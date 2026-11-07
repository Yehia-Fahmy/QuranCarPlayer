import Foundation
@testable import QuranCarPlayerCore

/// Records every command and lets tests emit engine events on demand.
@MainActor
final class FakeAudioEngine: AudioEngine {
    enum Command: Equatable {
        case load(URL, startAt: TimeInterval)
        case play
        case pause
        case seek(TimeInterval)
        case stop
    }

    var eventHandler: (@MainActor (AudioEngineEvent) -> Void)?
    private(set) var commands: [Command] = []
    private(set) var loadedItems: [EngineItem] = []
    var currentTime: TimeInterval = 0

    var currentItem: EngineItem? { loadedItems.last }
    var playCount: Int { commands.filter { $0 == .play }.count }
    var loadCount: Int { loadedItems.count }

    func load(_ item: EngineItem) {
        loadedItems.append(item)
        currentTime = item.startAt
        commands.append(.load(item.url, startAt: item.startAt))
    }

    func play() { commands.append(.play) }
    func pause() { commands.append(.pause) }
    func seek(to time: TimeInterval) {
        currentTime = time
        commands.append(.seek(time))
    }
    func stop() { commands.append(.stop) }

    func clearCommands() { commands.removeAll() }

    // MARK: Event helpers

    func emit(_ event: AudioEngineEvent) { eventHandler?(event) }

    /// Emit readyToPlay for the most recently loaded item.
    func becomeReady(duration: TimeInterval? = 120) {
        guard let item = currentItem else { return }
        emit(.readyToPlay(item.id, duration: duration))
    }

    func tick(to time: TimeInterval) {
        guard let item = currentItem else { return }
        currentTime = time
        emit(.timeUpdated(item.id, time))
    }

    func finishCurrent() {
        guard let item = currentItem else { return }
        emit(.playedToEnd(item.id))
    }

    func failCurrent(_ kind: EngineFailureKind, message: String = "test failure") {
        guard let item = currentItem else { return }
        emit(.failed(item.id, EngineFailure(kind: kind, message: message)))
    }

    func stallCurrent() {
        guard let item = currentItem else { return }
        emit(.stalled(item.id))
    }
}

/// Deterministic scheduler: tests fire scheduled work explicitly.
@MainActor
final class ManualScheduler: WorkScheduler {
    final class Work: ScheduledWork {
        let delay: TimeInterval
        let action: @MainActor () -> Void
        private(set) var isCancelled = false
        init(delay: TimeInterval, action: @escaping @MainActor () -> Void) {
            self.delay = delay
            self.action = action
        }
        func cancel() { isCancelled = true }
    }

    private(set) var scheduled: [Work] = []

    var pending: [Work] { scheduled.filter { !$0.isCancelled } }

    func schedule(after delay: TimeInterval, _ action: @escaping @MainActor () -> Void) -> ScheduledWork {
        let work = Work(delay: delay, action: action)
        scheduled.append(work)
        return work
    }

    /// Runs the oldest pending work item, returning its delay.
    @discardableResult
    func fireNext() -> TimeInterval? {
        guard let work = pending.first else { return nil }
        work.cancel()
        work.action()
        return work.delay
    }
}

final class ManualClock: Clock, @unchecked Sendable {
    private var current: Date
    init(_ start: Date = Date(timeIntervalSince1970: 1_700_000_000)) { current = start }
    func now() -> Date { current }
    func advance(by seconds: TimeInterval) { current = current.addingTimeInterval(seconds) }
}

// MARK: - Fixture helpers

enum Fixtures {
    static let toneURLs = [
        URL(fileURLWithPath: "/fixtures/tone-a.m4a"),
        URL(fileURLWithPath: "/fixtures/tone-b.m4a"),
        URL(fileURLWithPath: "/fixtures/tone-c.m4a"),
    ]

    static var reciterA: Reciter { FixtureAudioCatalog.fixtureReciters[0] }
    static var reciterB: Reciter { FixtureAudioCatalog.fixtureReciters[1] }

    static func recording(_ surah: Int, reciter: Reciter = reciterA) -> RecordingID {
        RecordingID(collection: reciter.collection.id, surahNumber: surah)
    }
}

/// Everything a coordinator test needs, wired together with fakes.
@MainActor
struct Harness {
    let engine = FakeAudioEngine()
    let scheduler = ManualScheduler()
    let clock = ManualClock()
    let sessionStore: InMemorySessionStore
    let settingsStore: InMemorySettingsStore
    let catalog: FixtureAudioCatalog
    let coordinator: PlaybackCoordinator

    init(savedSession: PlaybackSession? = nil,
         settings: AppSettings? = nil,
         unavailableSurahs: Set<Int> = [],
         retryPolicy: RetryPolicy = RetryPolicy()) throws {
        sessionStore = InMemorySessionStore(checkpoint: savedSession.map { SessionCheckpoint(session: $0) })
        settingsStore = InMemorySettingsStore(settings: settings)
        catalog = FixtureAudioCatalog(fixtureURLs: Fixtures.toneURLs, unavailableSurahs: unavailableSurahs)
        coordinator = PlaybackCoordinator(surahCatalog: try SurahCatalog.bundled(),
                                          audioCatalog: catalog,
                                          engine: engine,
                                          scheduler: scheduler,
                                          sessionStore: sessionStore,
                                          settingsStore: settingsStore,
                                          defaultReciter: FixtureAudioCatalog.defaultReciterID,
                                          clock: clock,
                                          retryPolicy: retryPolicy)
    }

    var snapshot: PlaybackSnapshot { coordinator.snapshot }

    /// Select a surah and let it become ready and play.
    func startPlaying(_ surah: Int, duration: TimeInterval? = 120) {
        coordinator.selectSurah(surah)
        engine.becomeReady(duration: duration)
    }
}
