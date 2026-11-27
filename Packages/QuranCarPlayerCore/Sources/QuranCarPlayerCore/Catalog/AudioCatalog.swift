import Foundation

public enum AudioCatalogError: Error, Equatable {
    case unknownReciter(ReciterID)
    case recordingUnavailable(RecordingID)
}

/// Source of reciters and playable recording URLs.
///
/// Resolution is synchronous: a production adapter is expected to resolve from a
/// validated, cached catalog, with refresh handled separately. This keeps the
/// playback coordinator deterministic and testable.
public protocol AudioCatalog: Sendable {
    var reciters: [Reciter] { get }
    func reciter(_ id: ReciterID) -> Reciter?
    func reciter(forCollection id: RecordingCollectionID) -> Reciter?
    func legacyCollection(for reciter: ReciterID) -> RecordingCollectionID?
    func source(for recording: RecordingID) throws -> RecordingSource
}

public extension AudioCatalog {
    func legacyCollection(for reciter: ReciterID) -> RecordingCollectionID? { nil }

    func reciter(_ id: ReciterID) -> Reciter? {
        reciters.first { $0.id == id }
    }

    func reciter(forCollection id: RecordingCollectionID) -> Reciter? {
        reciters.first { $0.collection.id == id }
    }
}

/// Keeps the identity and credits of previously saved editions available for local playback.
/// All new network sources come exclusively from the current catalog.
public struct CatalogWithLegacyDownloads: AudioCatalog {
    private let current: AudioCatalog
    private let legacy: AudioCatalog

    public init(current: AudioCatalog, legacy: AudioCatalog) {
        self.current = current
        self.legacy = legacy
    }

    public var reciters: [Reciter] { current.reciters }

    public func reciter(forCollection id: RecordingCollectionID) -> Reciter? {
        current.reciter(forCollection: id) ?? legacy.reciter(forCollection: id)
    }

    public func legacyCollection(for reciter: ReciterID) -> RecordingCollectionID? {
        legacy.reciter(reciter)?.collection.id
    }

    public func source(for recording: RecordingID) throws -> RecordingSource {
        try current.source(for: recording)
    }
}
