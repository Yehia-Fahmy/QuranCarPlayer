import Foundation
import Observation

/// Why automatic CarPlay resume did or did not happen. Exposed for tests and diagnostics.
public enum AutoResumeDecision: Equatable, Sendable {
    case resume
    case skippedDisabled
    case skippedAlreadyResumedThisConnection
    case skippedAlreadyActive
    case skippedNoSession
    case skippedSessionCompleted
    case skippedFailed
    /// Open policy decision (see DESIGN.md §6): a deliberately paused session is not auto-resumed.
    case skippedUserPaused
}

/// Token returned by `addObserver`. Observation stops when the token is deallocated or cancelled.
public final class ObservationToken {
    private let onCancel: () -> Void
    private var cancelled = false
    init(onCancel: @escaping () -> Void) { self.onCancel = onCancel }
    public func cancel() {
        guard !cancelled else { return }
        cancelled = true
        onCancel()
    }
    deinit { cancel() }
}

/// The single playback coordinator shared by phone, CarPlay, lock screen, steering wheel,
/// and automatic continuation. Views never create their own players or queues.
@Observable
@MainActor
public final class PlaybackCoordinator {

    // MARK: Dependencies

    public let surahCatalog: SurahCatalog
    public let audioCatalog: AudioCatalog
    public let retryPolicy: RetryPolicy
    public let checkpointInterval: TimeInterval
    /// Previous restarts the current surah when more than this many seconds have elapsed.
    public let previousRestartThreshold: TimeInterval = 3

    @ObservationIgnored private let engine: AudioEngine
    @ObservationIgnored private let scheduler: WorkScheduler
    @ObservationIgnored private let clock: Clock
    @ObservationIgnored private let sessionStore: SessionStore
    @ObservationIgnored private let settingsStore: SettingsStore

    // MARK: Observable state

    public private(set) var snapshot: PlaybackSnapshot
    public private(set) var settings: AppSettings

    // MARK: Operation tracking (not observable)

    /// Engine item that is allowed to affect state. Nil means nothing is loaded
    /// (lazy load on play) or the loaded item is considered dead.
    @ObservationIgnored private var currentItemID: EngineItemID?
    @ObservationIgnored private var hasHandledEnd = false
    @ObservationIgnored private var isSessionCompleted = false

    @ObservationIgnored private var retryAttempt = 0
    @ObservationIgnored private var firstFailureDate: Date?
    @ObservationIgnored private var retryWork: ScheduledWork?
    @ObservationIgnored private var retryResumePosition: TimeInterval = 0

    @ObservationIgnored private var lastCheckpointDate: Date?
    @ObservationIgnored private var didAutoResumeThisConnection = false

    @ObservationIgnored private var observers: [UUID: (PlaybackSnapshot) -> Void] = [:]

    // MARK: Init

    public init(surahCatalog: SurahCatalog,
                audioCatalog: AudioCatalog,
                engine: AudioEngine,
                scheduler: WorkScheduler,
                sessionStore: SessionStore,
                settingsStore: SettingsStore,
                defaultReciter: ReciterID,
                clock: Clock = SystemClock(),
                retryPolicy: RetryPolicy = RetryPolicy(),
                checkpointInterval: TimeInterval = 5) {
        self.surahCatalog = surahCatalog
        self.audioCatalog = audioCatalog
        self.engine = engine
        self.scheduler = scheduler
        self.sessionStore = sessionStore
        self.settingsStore = settingsStore
        self.clock = clock
        self.retryPolicy = retryPolicy
        self.checkpointInterval = checkpointInterval

        var loadedSettings = settingsStore.load() ?? AppSettings(preferredReciter: defaultReciter)
        if audioCatalog.reciter(loadedSettings.preferredReciter) == nil {
            loadedSettings.preferredReciter = defaultReciter
        }
        self.settings = loadedSettings
        self.snapshot = PlaybackSnapshot(selectedReciter: loadedSettings.preferredReciter,
                                         language: loadedSettings.language,
                                         automaticCarPlayResume: loadedSettings.automaticCarPlayResume)

        restoreCheckpoint()
        engine.eventHandler = { [weak self] event in self?.handleEngineEvent(event) }
    }

    /// Restore metadata only. Never starts audio or touches the engine.
    private func restoreCheckpoint() {
        guard let checkpoint = try? sessionStore.load() else { return }
        let session = checkpoint.session
        snapshot.currentRecording = session.recording
        snapshot.elapsed = session.elapsedSeconds
        snapshot.intent = .pause
        snapshot.isTestAudio = audioCatalog.reciter(forCollection: session.recording.collection)?.collection.isTestFixture ?? false
        if session.isCompleted {
            isSessionCompleted = true
            snapshot.transport = .completed
            snapshot.resumableSession = nil
        } else {
            snapshot.transport = .paused
            snapshot.pauseReason = session.lastPauseReason
            snapshot.resumableSession = session
        }
    }

    // MARK: Observation for non-SwiftUI consumers

    public func addObserver(_ handler: @escaping (PlaybackSnapshot) -> Void) -> ObservationToken {
        let id = UUID()
        observers[id] = handler
        handler(snapshot)
        return ObservationToken { [weak self] in
            Task { @MainActor in self?.observers[id] = nil }
        }
    }

    private func notifyObservers() {
        let current = snapshot
        for handler in observers.values { handler(current) }
    }

    // MARK: Lookup helpers

    public var currentSurah: Surah? {
        snapshot.currentSurahNumber.flatMap(surahCatalog.surah)
    }

    public var currentReciter: Reciter? {
        snapshot.currentRecording.flatMap { audioCatalog.reciter(forCollection: $0.collection) }
    }

    public var selectedReciter: Reciter? {
        audioCatalog.reciter(snapshot.selectedReciter)
    }

    public func reciter(for session: PlaybackSession) -> Reciter? {
        audioCatalog.reciter(forCollection: session.recording.collection)
    }

    // MARK: Selection

    /// Tapping a surah plays it immediately with the selected reciter, from the beginning.
    /// Selecting the current surah restarts it from zero.
    public func selectSurah(_ number: Int) {
        defer { notifyObservers() }
        guard Surah.numberRange.contains(number), let reciter = selectedReciter else { return }
        settings.surahListAnchor = number
        settingsStore.save(settings)
        load(recording: RecordingID(collection: reciter.collection.id, surahNumber: number), startAt: 0, intent: .play)
    }

    /// Changing reciters restarts the current surah with the new reciter at zero.
    /// Playing → restarts playing. Paused/failed/completed → zero, paused. No current → selection only.
    public func selectReciter(_ id: ReciterID) {
        defer { notifyObservers() }
        guard id != snapshot.selectedReciter, let reciter = audioCatalog.reciter(id) else { return }
        snapshot.selectedReciter = id
        settings.preferredReciter = id
        settingsStore.save(settings)
        guard let current = snapshot.currentRecording else { return }
        let intent: PlaybackIntent = snapshot.isActivelyPlaying ? .play : .pause
        load(recording: RecordingID(collection: reciter.collection.id, surahNumber: current.surahNumber), startAt: 0, intent: intent)
    }

    /// Resume the saved session at its saved position.
    public func continueListening() {
        defer { notifyObservers() }
        guard let session = snapshot.resumableSession else { return }
        load(recording: session.recording, startAt: session.elapsedSeconds, intent: .play)
    }

    // MARK: Transport

    public func play() {
        defer { notifyObservers() }
        guard let recording = snapshot.currentRecording else { return }
        switch snapshot.transport {
        case .completed:
            // Explicit play restarts surah 114 as a new session.
            load(recording: recording, startAt: 0, intent: .play)
        case .failed:
            retry()
        case .idle, .loading, .playing, .paused, .buffering, .retrying:
            snapshot.intent = .play
            snapshot.pauseReason = nil
            if currentItemID == nil {
                load(recording: recording, startAt: snapshot.elapsed, intent: .play)
            } else {
                engine.play()
                if snapshot.transport == .paused { snapshot.transport = .playing }
            }
        }
    }

    public func pause() {
        defer { notifyObservers() }
        pause(reason: .user)
    }

    public func togglePlayPause() {
        if snapshot.isActivelyPlaying { pause() } else { play() }
    }

    /// Next skips to the next surah with the same reciter. At 114 it is a no-op.
    public func next() {
        defer { notifyObservers() }
        guard let current = snapshot.currentRecording, current.surahNumber < Surah.numberRange.upperBound else { return }
        let intent: PlaybackIntent = snapshot.isActivelyPlaying ? .play : .pause
        load(recording: RecordingID(collection: current.collection, surahNumber: current.surahNumber + 1), startAt: 0, intent: intent)
    }

    /// Previous restarts the current surah after more than three seconds; otherwise it
    /// goes to the previous surah. At surah 1 it restarts surah 1.
    public func previous() {
        defer { notifyObservers() }
        guard let current = snapshot.currentRecording else { return }
        if snapshot.elapsed > previousRestartThreshold || current.surahNumber == Surah.numberRange.lowerBound {
            restartCurrent()
        } else {
            let intent: PlaybackIntent = snapshot.isActivelyPlaying ? .play : .pause
            load(recording: RecordingID(collection: current.collection, surahNumber: current.surahNumber - 1), startAt: 0, intent: intent)
        }
    }

    public func seek(to time: TimeInterval) {
        defer { notifyObservers() }
        guard snapshot.currentRecording != nil else { return }
        switch snapshot.transport {
        case .completed, .failed: return
        default: break
        }
        let upper = snapshot.duration ?? .greatestFiniteMagnitude
        let clamped = min(max(0, time), upper)
        snapshot.elapsed = clamped
        if currentItemID != nil { engine.seek(to: clamped) }
        checkpoint(force: true)
    }

    /// Retry the current recording at the retained position after a failure.
    public func retry() {
        defer { notifyObservers() }
        guard let recording = snapshot.currentRecording else { return }
        guard case .failed = snapshot.transport else { return }
        resetRetryState()
        load(recording: recording, startAt: snapshot.elapsed, intent: .play)
    }

    // MARK: Settings

    public func setLanguage(_ language: LanguagePreference) {
        defer { notifyObservers() }
        settings.language = language
        snapshot.language = language
        settingsStore.save(settings)
    }

    public func setAutomaticCarPlayResume(_ enabled: Bool) {
        defer { notifyObservers() }
        settings.automaticCarPlayResume = enabled
        snapshot.automaticCarPlayResume = enabled
        settingsStore.save(settings)
    }

    /// Stable surah number the list should anchor to on return. UI preference, not progress.
    public func setSurahListAnchor(_ number: Int?) {
        settings.surahListAnchor = number
        settingsStore.save(settings)
    }

    /// Anchor for the surah list: explicit UI anchor, else current surah, else nil.
    public var surahListAnchor: Int? {
        settings.surahListAnchor ?? snapshot.listAnchorSurahNumber
    }

    // MARK: CarPlay connection lifecycle

    /// Decide whether connecting to CarPlay should resume the prior session.
    public func evaluateAutomaticResume() -> AutoResumeDecision {
        guard snapshot.automaticCarPlayResume else { return .skippedDisabled }
        guard !didAutoResumeThisConnection else { return .skippedAlreadyResumedThisConnection }
        guard snapshot.currentRecording != nil else { return .skippedNoSession }
        switch snapshot.transport {
        case .playing, .buffering, .loading, .retrying: return .skippedAlreadyActive
        case .completed: return .skippedSessionCompleted
        case .failed: return .skippedFailed
        case .idle: return .skippedNoSession
        case .paused:
            if snapshot.pauseReason == .user { return .skippedUserPaused }
            return .resume
        }
    }

    /// Call when the CarPlay scene connects. Resumes at most once per connection.
    @discardableResult
    public func carPlayDidConnect() -> AutoResumeDecision {
        defer { notifyObservers() }
        didAutoResumeThisConnection = false
        let decision = evaluateAutomaticResume()
        if decision == .resume {
            didAutoResumeThisConnection = true
            play()
        }
        return decision
    }

    /// Call when the CarPlay scene disconnects: pause, save, cancel retries.
    public func carPlayDidDisconnect() {
        defer { notifyObservers() }
        didAutoResumeThisConnection = false
        pause(reason: .carDisconnected)
    }

    // MARK: Audio session events (forwarded by the platform layer)

    public func interruptionBegan() {
        defer { notifyObservers() }
        pause(reason: .interruption)
    }

    /// Resume only if we paused for this interruption and the system says resumption is appropriate.
    /// A deliberate user pause during the interruption prevents resumption.
    public func interruptionEnded(shouldResume: Bool) {
        defer { notifyObservers() }
        guard shouldResume, snapshot.transport == .paused, snapshot.pauseReason == .interruption else { return }
        play()
    }

    /// The output route (e.g. the car) went away. Pause; never transfer to the phone speaker.
    public func audioRouteLost() {
        defer { notifyObservers() }
        pause(reason: .routeLost)
    }

    /// Media services were reset: the engine item is unusable and must be reloaded.
    public func mediaServicesWereReset() {
        defer { notifyObservers() }
        let wasActive = snapshot.isActivelyPlaying
        currentItemID = nil
        engine.stop()
        if wasActive, let recording = snapshot.currentRecording {
            load(recording: recording, startAt: snapshot.elapsed, intent: .play)
        }
    }

    // MARK: Loading

    /// Single entry point for every selection. Each call invalidates all prior engine callbacks.
    private func load(recording: RecordingID, startAt: TimeInterval, intent: PlaybackIntent) {
        cancelRetry()
        resetRetryState()
        hasHandledEnd = false
        isSessionCompleted = false
        currentItemID = nil

        snapshot.currentRecording = recording
        snapshot.elapsed = max(0, startAt)
        snapshot.duration = nil
        snapshot.intent = intent
        snapshot.pauseReason = intent == .pause ? .user : nil

        let source: RecordingSource
        do {
            source = try audioCatalog.source(for: recording)
        } catch {
            engine.stop()
            snapshot.isTestAudio = false
            snapshot.transport = .failed(PlaybackFailure(recording: recording, reason: .recordingUnavailable))
            checkpoint(force: true)
            return
        }
        snapshot.isTestAudio = source.isTestFixture

        if intent == .play {
            let item = EngineItem(url: source.url, startAt: snapshot.elapsed)
            currentItemID = item.id
            engine.load(item)
            snapshot.transport = .loading
        } else {
            // Leave paused and unloaded; `play()` loads lazily at `snapshot.elapsed`.
            engine.stop()
            snapshot.transport = .paused
        }
        checkpoint(force: true)
    }

    private func restartCurrent() {
        guard let recording = snapshot.currentRecording else { return }
        switch snapshot.transport {
        case .playing, .paused, .buffering:
            if currentItemID != nil {
                snapshot.elapsed = 0
                engine.seek(to: 0)
                checkpoint(force: true)
                return
            }
            load(recording: recording, startAt: 0, intent: snapshot.intent)
        default:
            let intent: PlaybackIntent = snapshot.isActivelyPlaying ? .play : .pause
            load(recording: recording, startAt: 0, intent: intent)
        }
    }

    private func pause(reason: PauseReason) {
        guard snapshot.currentRecording != nil else { return }
        switch snapshot.transport {
        case .idle, .completed, .failed:
            return
        case .paused:
            // A deliberate user pause overrides a system pause reason; system reasons never
            // override a deliberate pause.
            if reason == .user {
                snapshot.pauseReason = .user
                snapshot.intent = .pause
                checkpoint(force: true)
            }
            return
        case .loading, .playing, .buffering, .retrying:
            break
        }
        cancelRetry()
        if currentItemID != nil {
            engine.pause()
        } else if case .retrying = snapshot.transport {
            snapshot.elapsed = retryResumePosition
        }
        // `snapshot.elapsed` is authoritative: it is updated by seeks and periodic time events,
        // whereas the engine's clock can lag a just-issued seek.
        snapshot.intent = .pause
        snapshot.pauseReason = reason
        snapshot.transport = .paused
        checkpoint(force: true)
    }

    // MARK: Engine events

    private func isCurrent(_ id: EngineItemID) -> Bool { id == currentItemID }

    private func handleEngineEvent(_ event: AudioEngineEvent) {
        defer { notifyObservers() }
        switch event {
        case .readyToPlay(let id, let duration):
            guard isCurrent(id) else { return }
            applyDuration(duration)
            resetRetryState()
            if snapshot.intent == .play {
                engine.play()
                snapshot.transport = .playing
            } else {
                engine.pause()
                snapshot.transport = .paused
            }

        case .durationChanged(let id, let duration):
            guard isCurrent(id) else { return }
            applyDuration(duration)

        case .timeUpdated(let id, let time):
            guard isCurrent(id) else { return }
            snapshot.elapsed = time
            if case .retrying = snapshot.transport, snapshot.intent == .play {
                // The stalled item recovered on its own.
                cancelRetry()
                resetRetryState()
                snapshot.transport = .playing
            }
            if snapshot.transport == .playing { checkpoint(force: false) }

        case .buffering(let id):
            guard isCurrent(id), snapshot.transport == .playing else { return }
            snapshot.transport = .buffering

        case .resumedPlaying(let id):
            guard isCurrent(id) else { return }
            if snapshot.intent == .play {
                if case .retrying = snapshot.transport {
                    cancelRetry()
                    resetRetryState()
                }
                snapshot.transport = .playing
            } else {
                engine.pause()
            }

        case .stalled(let id):
            guard isCurrent(id), snapshot.intent == .play else { return }
            // Keep the item: AVPlayer often recovers. Reload only if the watchdog fires.
            scheduleRetry(position: snapshot.elapsed, killItem: false)

        case .playedToEnd(let id):
            guard isCurrent(id), !hasHandledEnd else { return }
            hasHandledEnd = true
            advanceAfterNaturalEnd()

        case .failed(let id, let failure):
            guard isCurrent(id) else { return }
            handleFailure(failure)
        }
    }

    private func applyDuration(_ duration: TimeInterval?) {
        guard let duration, duration.isFinite, duration > 0 else {
            snapshot.duration = nil
            return
        }
        snapshot.duration = duration
        // Clamp a restored position to the real duration once metadata is known.
        if snapshot.elapsed > duration {
            snapshot.elapsed = duration
            engine.seek(to: duration)
        }
    }

    /// Advance exactly once. Stops after An-Nas; never loops.
    private func advanceAfterNaturalEnd() {
        guard let current = snapshot.currentRecording else { return }
        if current.surahNumber >= Surah.numberRange.upperBound {
            currentItemID = nil
            engine.stop()
            isSessionCompleted = true
            snapshot.intent = .pause
            snapshot.pauseReason = nil
            if let duration = snapshot.duration { snapshot.elapsed = duration }
            snapshot.transport = .completed
            checkpoint(force: true)
        } else {
            load(recording: RecordingID(collection: current.collection, surahNumber: current.surahNumber + 1),
                 startAt: 0, intent: .play)
        }
    }

    // MARK: Failure and retry

    private func handleFailure(_ failure: EngineFailure) {
        let reason: PlaybackFailureReason
        switch failure.kind {
        case .network: reason = .networkUnavailable
        case .missingRecording: reason = .recordingUnavailable
        case .notPermitted: reason = .notPermitted
        case .unknown: reason = .unknown(failure.message)
        }
        if snapshot.intent == .play, failure.isRetriable {
            scheduleRetry(position: snapshot.elapsed, killItem: true, exhaustedReason: reason)
        } else {
            fail(with: reason, position: snapshot.elapsed)
        }
    }

    /// Actionable failure: keep the recording and position visible, offer Retry.
    private func fail(with reason: PlaybackFailureReason, position: TimeInterval) {
        guard let recording = snapshot.currentRecording else { return }
        currentItemID = nil
        engine.stop()
        cancelRetry()
        snapshot.elapsed = position
        snapshot.transport = .failed(PlaybackFailure(recording: recording, reason: reason))
        checkpoint(force: true)
    }

    /// Schedules the next bounded retry, or fails with `exhaustedReason` when the policy is exhausted.
    private func scheduleRetry(position: TimeInterval, killItem: Bool, exhaustedReason: PlaybackFailureReason = .networkUnavailable) {
        let now = clock.now()
        if firstFailureDate == nil { firstFailureDate = now; retryAttempt = 0 }
        let elapsedSinceFirst = now.timeIntervalSince(firstFailureDate ?? now)
        guard let delay = retryPolicy.delay(forAttempt: retryAttempt, elapsedSinceFirstFailure: elapsedSinceFirst) else {
            fail(with: exhaustedReason, position: position)
            return
        }
        if killItem { currentItemID = nil }
        retryResumePosition = position
        retryAttempt += 1
        snapshot.transport = .retrying(attempt: retryAttempt)
        retryWork?.cancel()
        retryWork = scheduler.schedule(after: delay) { [weak self] in self?.performRetry() }
        checkpoint(force: true)
    }

    private func performRetry() {
        defer { notifyObservers() }
        retryWork = nil
        guard snapshot.intent == .play, case .retrying = snapshot.transport, let recording = snapshot.currentRecording else { return }
        hasHandledEnd = false
        do {
            let source = try audioCatalog.source(for: recording)
            let item = EngineItem(url: source.url, startAt: retryResumePosition)
            currentItemID = item.id
            snapshot.elapsed = retryResumePosition
            engine.load(item)
            snapshot.transport = .loading
        } catch {
            currentItemID = nil
            engine.stop()
            snapshot.transport = .failed(PlaybackFailure(recording: recording, reason: .recordingUnavailable))
            checkpoint(force: true)
        }
    }

    private func cancelRetry() {
        retryWork?.cancel()
        retryWork = nil
    }

    private func resetRetryState() {
        retryAttempt = 0
        firstFailureDate = nil
    }

    // MARK: Checkpoints

    private func checkpoint(force: Bool) {
        guard let recording = snapshot.currentRecording else { return }
        let now = clock.now()
        if !force, let last = lastCheckpointDate, now.timeIntervalSince(last) < checkpointInterval { return }
        lastCheckpointDate = now
        let session = PlaybackSession(recording: recording,
                                      elapsedSeconds: snapshot.elapsed,
                                      isCompleted: isSessionCompleted,
                                      checkpointDate: now,
                                      lastPauseReason: snapshot.transport == .paused ? snapshot.pauseReason : nil)
        try? sessionStore.save(SessionCheckpoint(session: session))
        snapshot.resumableSession = isSessionCompleted ? nil : session
    }
}
