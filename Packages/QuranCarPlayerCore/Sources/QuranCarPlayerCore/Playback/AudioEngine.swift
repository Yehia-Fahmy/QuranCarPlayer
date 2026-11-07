import Foundation

/// Identifies one load request so stale engine callbacks can be discarded.
public struct EngineItemID: Hashable, Sendable {
    public let rawValue: UUID
    public init() { rawValue = UUID() }
}

/// What the engine was asked to load.
public struct EngineItem: Equatable, Sendable {
    public let id: EngineItemID
    public let url: URL
    public let startAt: TimeInterval

    public init(id: EngineItemID = EngineItemID(), url: URL, startAt: TimeInterval) {
        self.id = id
        self.url = url
        self.startAt = startAt
    }
}

/// Coarse classification of engine failures so policy can decide retry vs. actionable error.
public enum EngineFailureKind: Equatable, Sendable {
    /// Transient connectivity problem; bounded retry is appropriate.
    case network
    /// File missing, 404, unsupported format: retrying will not help.
    case missingRecording
    /// Authentication / permission failure: do not retry automatically.
    case notPermitted
    /// Anything else.
    case unknown
}

public struct EngineFailure: Error, Equatable, Sendable {
    public let kind: EngineFailureKind
    public let message: String
    public init(kind: EngineFailureKind, message: String) {
        self.kind = kind
        self.message = message
    }
    public var isRetriable: Bool { kind == .network || kind == .unknown }
}

/// Events emitted by the engine. Every event names the item it concerns.
public enum AudioEngineEvent: Equatable, Sendable {
    case readyToPlay(EngineItemID, duration: TimeInterval?)
    case durationChanged(EngineItemID, TimeInterval?)
    case timeUpdated(EngineItemID, TimeInterval)
    case buffering(EngineItemID)
    case resumedPlaying(EngineItemID)
    case stalled(EngineItemID)
    case playedToEnd(EngineItemID)
    case failed(EngineItemID, EngineFailure)
}

/// Thin transport abstraction over AVPlayer (or a fake in tests).
///
/// The engine owns no playback policy. All decisions live in `PlaybackCoordinator`.
@MainActor
public protocol AudioEngine: AnyObject {
    var eventHandler: (@MainActor (AudioEngineEvent) -> Void)? { get set }
    /// Replaces any current item. Does not start playback.
    func load(_ item: EngineItem)
    func play()
    func pause()
    func seek(to time: TimeInterval)
    /// Unloads the current item and releases resources.
    func stop()
    var currentTime: TimeInterval { get }
}
