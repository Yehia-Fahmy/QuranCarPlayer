import Foundation

/// Test-owned catalog that maps every surah to synthetic tone files.
///
/// This exists so the app can be developed and exercised before production audio
/// permissions are resolved. Reciter names deliberately describe the audio as test
/// tones; the audio must never be presented as Quran recitation.
public struct FixtureAudioCatalog: AudioCatalog {
    public static let providerKey = "fixture"

    public let reciters: [Reciter]
    /// Tone files, cycled across surah numbers.
    public let fixtureURLs: [URL]
    /// Surahs that deliberately fail to resolve, to exercise error paths.
    public let unavailableSurahs: Set<Int>

    public init(fixtureURLs: [URL], unavailableSurahs: Set<Int> = []) {
        precondition(!fixtureURLs.isEmpty, "at least one fixture URL is required")
        self.fixtureURLs = fixtureURLs
        self.unavailableSurahs = unavailableSurahs
        self.reciters = FixtureAudioCatalog.fixtureReciters
    }

    public static let fixtureReciters: [Reciter] = [
        Reciter(id: ReciterID("fixture.toneA"),
                arabicName: "نغمة اختبار أ (ليست قرآنًا)",
                englishName: "Test Tone A (not Quran)",
                collection: RecordingCollection(id: RecordingCollectionID(provider: providerKey, collection: "toneA"),
                                                riwayah: "n/a (test fixture)",
                                                attribution: "Synthetic test tones generated in this repository.",
                                                isTestFixture: true)),
        Reciter(id: ReciterID("fixture.toneB"),
                arabicName: "نغمة اختبار ب (ليست قرآنًا)",
                englishName: "Test Tone B (not Quran)",
                collection: RecordingCollection(id: RecordingCollectionID(provider: providerKey, collection: "toneB"),
                                                riwayah: "n/a (test fixture)",
                                                attribution: "Synthetic test tones generated in this repository.",
                                                isTestFixture: true)),
    ]

    public static var defaultReciterID: ReciterID { fixtureReciters[0].id }

    public func source(for recording: RecordingID) throws -> RecordingSource {
        guard reciter(forCollection: recording.collection) != nil else {
            throw AudioCatalogError.recordingUnavailable(recording)
        }
        guard !unavailableSurahs.contains(recording.surahNumber) else {
            throw AudioCatalogError.recordingUnavailable(recording)
        }
        // Offset by collection so two "reciters" play different tones for the same surah.
        let collectionOffset = recording.collection.collection == "toneB" ? 1 : 0
        let url = fixtureURLs[(recording.surahNumber - 1 + collectionOffset) % fixtureURLs.count]
        return RecordingSource(id: recording, url: url, isTestFixture: true)
    }
}
