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
    func source(for recording: RecordingID) throws -> RecordingSource
}

public extension AudioCatalog {
    func reciter(_ id: ReciterID) -> Reciter? {
        reciters.first { $0.id == id }
    }

    func reciter(forCollection id: RecordingCollectionID) -> Reciter? {
        reciters.first { $0.collection.id == id }
    }
}
