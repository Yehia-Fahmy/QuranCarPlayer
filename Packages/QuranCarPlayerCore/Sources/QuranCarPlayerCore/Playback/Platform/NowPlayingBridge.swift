#if canImport(MediaPlayer)
import Foundation
import MediaPlayer

/// Localized text the bridge needs but does not own.
public struct NowPlayingLabels: Sendable {
    /// Shown in place of an album title when the audio is a test fixture.
    public let testAudioNotice: String
    public init(testAudioNotice: String) { self.testAudioNotice = testAudioNotice }
}

/// Publishes Now Playing metadata and routes remote commands (lock screen, CarPlay
/// Now Playing, steering wheel, headphones) into the shared coordinator.
@MainActor
public final class NowPlayingBridge {
    private let coordinator: PlaybackCoordinator
    private let labels: @MainActor (ResolvedLanguage) -> NowPlayingLabels
    private let infoCenter = MPNowPlayingInfoCenter.default()
    private let commandCenter = MPRemoteCommandCenter.shared()
    private var observation: ObservationToken?
    private var targets: [(MPRemoteCommand, Any)] = []

    public init(coordinator: PlaybackCoordinator,
                labels: @escaping @MainActor (ResolvedLanguage) -> NowPlayingLabels) {
        self.coordinator = coordinator
        self.labels = labels
        registerCommands()
        observation = coordinator.addObserver { [weak self] snapshot in
            self?.update(with: snapshot)
        }
    }

    deinit {
        for (command, target) in targets { command.removeTarget(target) }
    }

    // MARK: Remote commands

    private func registerCommands() {
        add(commandCenter.playCommand) { coordinator in coordinator.play(); return .success }
        add(commandCenter.pauseCommand) { coordinator in coordinator.pause(); return .success }
        add(commandCenter.togglePlayPauseCommand) { coordinator in coordinator.togglePlayPause(); return .success }
        add(commandCenter.nextTrackCommand) { coordinator in
            guard coordinator.snapshot.canSkipForward else { return .noActionableNowPlayingItem }
            coordinator.next(); return .success
        }
        add(commandCenter.previousTrackCommand) { coordinator in coordinator.previous(); return .success }
        add(commandCenter.changePlaybackPositionCommand) { coordinator, event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            coordinator.seek(to: event.positionTime); return .success
        }
        // Not part of the design: no seek-by-interval, shuffle, repeat, rating, or like/dislike.
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
        commandCenter.changeRepeatModeCommand.isEnabled = false
        commandCenter.changeShuffleModeCommand.isEnabled = false
        commandCenter.seekForwardCommand.isEnabled = false
        commandCenter.seekBackwardCommand.isEnabled = false
    }

    private func add(_ command: MPRemoteCommand,
                     _ handler: @escaping @MainActor (PlaybackCoordinator) -> MPRemoteCommandHandlerStatus) {
        add(command) { coordinator, _ in handler(coordinator) }
    }

    private func add(_ command: MPRemoteCommand,
                     _ handler: @escaping @MainActor (PlaybackCoordinator, MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus) {
        command.isEnabled = true
        let target = command.addTarget { [weak self] event in
            // Remote commands are delivered on the main thread.
            MainActor.assumeIsolated {
                guard let self else { return .commandFailed }
                return handler(self.coordinator, event)
            }
        }
        targets.append((command, target))
    }

    // MARK: Metadata

    private func update(with snapshot: PlaybackSnapshot) {
        commandCenter.nextTrackCommand.isEnabled = snapshot.canSkipForward
        commandCenter.previousTrackCommand.isEnabled = snapshot.canSkipBackward
        commandCenter.changePlaybackPositionCommand.isEnabled = snapshot.duration != nil && snapshot.currentRecording != nil

        guard snapshot.currentRecording != nil, let surah = coordinator.currentSurah else {
            infoCenter.nowPlayingInfo = nil
            return
        }
        let language = snapshot.language.resolved()
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: "\(surah.number). \(surah.displayName(for: language))",
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyIsLiveStream: false,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: snapshot.elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: snapshot.transport == .playing ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
        ]
        if let reciter = coordinator.currentReciter {
            info[MPMediaItemPropertyArtist] = reciter.displayName(for: language)
        }
        if snapshot.isTestAudio {
            info[MPMediaItemPropertyAlbumTitle] = labels(language).testAudioNotice
        }
        // Only report a duration when it is actually known; never fabricate progress.
        if let duration = snapshot.duration {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        infoCenter.nowPlayingInfo = info
    }
}
#endif
