import Foundation

/// Why the current item cannot play. Shown with a Retry action.
public enum PlaybackFailureReason: Equatable, Sendable {
    /// Transient network trouble; automatic retries were exhausted.
    case networkUnavailable
    /// The recording is missing, unreadable, or the catalog could not resolve it.
    case recordingUnavailable
    /// The provider refused access.
    case notPermitted
    case unknown(String)
}

public struct PlaybackFailure: Equatable, Sendable {
    public let recording: RecordingID
    public let reason: PlaybackFailureReason
    public init(recording: RecordingID, reason: PlaybackFailureReason) {
        self.recording = recording
        self.reason = reason
    }
}

/// Transport state, kept separate from user intent.
public enum TransportState: Equatable, Sendable {
    case idle
    case loading
    case playing
    case paused
    case buffering
    /// Waiting for a scheduled automatic retry.
    case retrying(attempt: Int)
    case failed(PlaybackFailure)
    /// Surah 114 finished. Reconnecting must not restart it.
    case completed
}

/// What the user most recently asked for.
public enum PlaybackIntent: Equatable, Sendable {
    case play
    case pause
}

/// Observable snapshot consumed by phone, CarPlay, and Now Playing bridges.
public struct PlaybackSnapshot: Equatable, Sendable {
    public var transport: TransportState = .idle
    public var intent: PlaybackIntent = .pause
    public var pauseReason: PauseReason?
    /// Current recording loaded (or attempted), independent of transport state.
    public var currentRecording: RecordingID?
    public var elapsed: TimeInterval = 0
    /// Nil until metadata loads. UI must not fabricate progress when nil.
    public var duration: TimeInterval?
    public var isTestAudio = false
    /// Saved session eligible for Continue Listening (nil when none or completed).
    public var resumableSession: PlaybackSession?
    public var selectedReciter: ReciterID
    public var language: LanguagePreference
    public var automaticCarPlayResume: Bool

    public init(selectedReciter: ReciterID, language: LanguagePreference, automaticCarPlayResume: Bool) {
        self.selectedReciter = selectedReciter
        self.language = language
        self.automaticCarPlayResume = automaticCarPlayResume
    }

    public var currentSurahNumber: Int? { currentRecording?.surahNumber }

    public var isActivelyPlaying: Bool {
        switch transport {
        case .playing, .buffering, .loading, .retrying: return intent == .play
        default: return false
        }
    }

    /// Whether Next should be enabled.
    public var canSkipForward: Bool {
        guard let n = currentSurahNumber else { return false }
        return n < Surah.numberRange.upperBound
    }

    /// Whether Previous should be enabled (always true with a current item: it can restart).
    public var canSkipBackward: Bool { currentRecording != nil }

    /// Anchor for the surah list: explicit UI anchor is handled by settings; this is the fallback.
    public var listAnchorSurahNumber: Int? { currentSurahNumber ?? resumableSession?.recording.surahNumber }
}
