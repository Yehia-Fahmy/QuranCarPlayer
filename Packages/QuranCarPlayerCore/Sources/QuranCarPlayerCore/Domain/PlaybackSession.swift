import Foundation

/// Why playback is currently paused. Drives interruption and automatic-resume policy.
public enum PauseReason: String, Codable, Sendable, Equatable {
    /// The user explicitly paused (phone, car, lock screen, steering wheel).
    case user
    /// Playback paused because the CarPlay scene disconnected.
    case carDisconnected
    /// Playback paused because the audio route (e.g. car audio) went away.
    case routeLost
    /// A system interruption (call, Siri, navigation prompt) paused playback.
    case interruption
}

/// The persisted listening session used for Continue Listening.
public struct PlaybackSession: Codable, Equatable, Sendable {
    public var recording: RecordingID
    public var elapsedSeconds: Double
    public var isCompleted: Bool
    public var checkpointDate: Date
    /// Reason for the last pause, if paused. Nil while playing or when unknown.
    public var lastPauseReason: PauseReason?

    public init(recording: RecordingID,
                elapsedSeconds: Double,
                isCompleted: Bool = false,
                checkpointDate: Date,
                lastPauseReason: PauseReason? = nil) {
        self.recording = recording
        self.elapsedSeconds = elapsedSeconds
        self.isCompleted = isCompleted
        self.checkpointDate = checkpointDate
        self.lastPauseReason = lastPauseReason
    }
}

/// Versioned on-disk envelope so future format changes can migrate or discard safely.
public struct SessionCheckpoint: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public var version: Int
    public var session: PlaybackSession

    public init(version: Int = SessionCheckpoint.currentVersion, session: PlaybackSession) {
        self.version = version
        self.session = session
    }
}
