#if os(iOS)
import Foundation
import AVFAudio

/// Configures the playback audio session and forwards interruption, route-change,
/// and media-services-reset notifications to the coordinator.
@MainActor
public final class AudioSessionController {
    private let coordinator: PlaybackCoordinator
    private let engine: AVPlayerEngine
    private let session = AVAudioSession.sharedInstance()
    private var tokens: [NSObjectProtocol] = []
    private var observation: ObservationToken?
    private let sessionQueue = DispatchQueue(label: "QuranCarPlayer.AudioSession")
    private var pendingSessionChange: DispatchWorkItem?
    private var requestedActive: Bool? = false
    private var sessionGeneration: UInt = 0
    private var lastTransport: TransportState?
    private var isInterrupted = false

    public init(coordinator: PlaybackCoordinator, engine: AVPlayerEngine) {
        self.coordinator = coordinator
        self.engine = engine
        configureCategory()
        subscribe()
        observation = coordinator.addObserver { [weak self] snapshot in
            guard let self, self.lastTransport != snapshot.transport else { return }
            self.lastTransport = snapshot.transport
            if snapshot.transport == .playing && !self.isInterrupted {
                self.requestSession(active: true)
            } else if !snapshot.isActivelyPlaying {
                self.requestSession(active: false)
            }
        }
    }

    deinit {
        for token in tokens { NotificationCenter.default.removeObserver(token) }
    }

    private func configureCategory() {
        do {
            try session.setCategory(.playback, mode: .default)
        } catch {
            // Category failures are non-fatal; playback may still work with the default category.
        }
    }

    private func requestSession(active: Bool) {
        guard requestedActive != active else { return }
        requestedActive = active
        sessionGeneration &+= 1
        pendingSessionChange?.cancel()
        applySession(active: active, generation: sessionGeneration, attempt: 0)
    }

    private func applySession(active: Bool, generation: UInt, attempt: Int) {
        // setActive is synchronous on our minimum OS. Serialize requests off the main
        // thread so pause/play or a route change always leaves the newest request last.
        let change = DispatchWorkItem { [weak self, session] in
            do {
                try session.setActive(active, options: active ? [] : .notifyOthersOnDeactivation)
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.sessionGeneration == generation else { return }
                    if attempt < 2 {
                        self.applySession(active: active, generation: generation, attempt: attempt + 1)
                    } else {
                        // A later transport transition may retry. Periodic time updates do not.
                        self.requestedActive = nil
                    }
                }
            }
        }
        pendingSessionChange = change
        sessionQueue.asyncAfter(deadline: .now() + Double(attempt) * 0.5, execute: change)
    }

    private func invalidateSessionRequests() {
        lastTransport = nil
        // A queued activation could already be executing. Finish it before releasing focus.
        requestedActive = nil
        requestSession(active: false)
    }

    private func subscribe() {
        let center = NotificationCenter.default

        tokens.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: .main) { [weak self] note in
            guard let info = note.userInfo,
                  let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
            let rawOptions = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let shouldResume = AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume)
            MainActor.assumeIsolated {
                guard let self else { return }
                switch type {
                case .began:
                    self.isInterrupted = true
                    self.invalidateSessionRequests()
                    self.coordinator.interruptionBegan()
                case .ended:
                    self.isInterrupted = false
                    self.coordinator.interruptionEnded(shouldResume: shouldResume)
                @unknown default:
                    break
                }
            }
        })

        tokens.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: session, queue: .main) { [weak self] note in
            guard let rawReason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason) else { return }
            MainActor.assumeIsolated {
                guard let self else { return }
                // The previous output (e.g. the car or headphones) went away: pause and never
                // transfer playback to the phone speaker automatically.
                if reason == .oldDeviceUnavailable {
                    self.coordinator.audioRouteLost()
                }
            }
        })

        tokens.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: session, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isInterrupted = false
                self.invalidateSessionRequests()
                self.configureCategory()
                self.engine.recreatePlayer()
                self.coordinator.mediaServicesWereReset()
            }
        })
    }
}
#endif
