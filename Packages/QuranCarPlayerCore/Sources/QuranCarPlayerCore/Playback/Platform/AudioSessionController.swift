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
    private var isActive = false

    public init(coordinator: PlaybackCoordinator, engine: AVPlayerEngine) {
        self.coordinator = coordinator
        self.engine = engine
        configureCategory()
        subscribe()
        observation = coordinator.addObserver { [weak self] snapshot in
            // Activate only when audio is actually about to play (HIG: do not silence
            // other sources, such as the car radio, before you are ready).
            if snapshot.transport == .playing { self?.activateIfNeeded() }
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

    private func activateIfNeeded() {
        guard !isActive else { return }
        do {
            try session.setActive(true)
            isActive = true
        } catch {
            isActive = false
        }
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
                    self.coordinator.interruptionBegan()
                case .ended:
                    self.isActive = false
                    if shouldResume { self.activateIfNeeded() }
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
                self.isActive = false
                self.configureCategory()
                self.engine.recreatePlayer()
                self.coordinator.mediaServicesWereReset()
            }
        })
    }
}
#endif
