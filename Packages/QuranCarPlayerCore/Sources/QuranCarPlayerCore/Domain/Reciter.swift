import Foundation

/// Stable identifier for a reciter. Never use localized names as keys.
public struct ReciterID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
}

/// Identifies one complete recording collection from one provider.
/// A timestamp saved against one collection must never be applied to another.
public struct RecordingCollectionID: Hashable, Codable, Sendable {
    /// Provider key, e.g. "fixture" or a future production provider key.
    public let provider: String
    /// Provider-specific collection key (e.g. a provider's reciter/moshaf id).
    public let collection: String

    public init(provider: String, collection: String) {
        self.provider = provider
        self.collection = collection
    }
}

/// A complete recording collection for one reciter (one riwayah, one set of 114 files).
public struct RecordingCollection: Hashable, Codable, Sendable {
    public let id: RecordingCollectionID
    /// Transmission, e.g. "Hafs an Asim". Collections must not be mixed implicitly.
    public let riwayah: String
    /// Attribution text that must be surfaced in the app for this collection.
    public let attribution: String
    /// True when the audio is test-owned fixture audio and must never be
    /// presented as Quran recitation.
    public let isTestFixture: Bool

    public init(id: RecordingCollectionID, riwayah: String, attribution: String, isTestFixture: Bool) {
        self.id = id
        self.riwayah = riwayah
        self.attribution = attribution
        self.isTestFixture = isTestFixture
    }
}

public struct Reciter: Identifiable, Hashable, Codable, Sendable {
    public let id: ReciterID
    public let arabicName: String
    public let englishName: String
    public let collection: RecordingCollection

    public init(id: ReciterID, arabicName: String, englishName: String, collection: RecordingCollection) {
        self.id = id
        self.arabicName = arabicName
        self.englishName = englishName
        self.collection = collection
    }

    public func displayName(for language: ResolvedLanguage) -> String {
        switch language {
        case .arabic: return arabicName
        case .english: return englishName
        }
    }
}

/// Identity of a single recording: one surah within one collection.
public struct RecordingID: Hashable, Codable, Sendable {
    public let collection: RecordingCollectionID
    public let surahNumber: Int

    public init(collection: RecordingCollectionID, surahNumber: Int) {
        precondition(Surah.numberRange.contains(surahNumber), "surah number out of range")
        self.collection = collection
        self.surahNumber = surahNumber
    }
}

/// A playable source resolved from a `RecordingID`.
public struct RecordingSource: Hashable, Sendable {
    public let id: RecordingID
    public let url: URL
    public let isTestFixture: Bool

    public init(id: RecordingID, url: URL, isTestFixture: Bool) {
        self.id = id
        self.url = url
        self.isTestFixture = isTestFixture
    }
}
