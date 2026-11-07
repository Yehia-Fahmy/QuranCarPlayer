import Foundation
import Testing
@testable import QuranCarPlayerCore

@Suite("MP3Quran catalog")
struct MP3QuranCatalogTests {
    @Test("Bundled snapshot streams the four complete Hafs collections")
    func bundledReciters() throws {
        let catalog = try MP3QuranCatalog.bundled()
        #expect(catalog.reciters.map(\.englishName) == [
            "Maher Al-Muaiqly",
            "Mishary Rashid Alafasy",
            "Abdul Rahman Al-Sudais",
            "Saud Al-Shuraim",
        ])
        #expect(catalog.reciters.map(\.arabicName) == [
            "ماهر المعيقلي",
            "مشاري العفاسي",
            "عبدالرحمن السديس",
            "سعود الشريم",
        ])
        #expect(catalog.reciters.allSatisfy { $0.collection.isTestFixture == false })
        #expect(catalog.reciters.allSatisfy { $0.collection.riwayah == "Hafs an Asim · Murattal" })
        #expect(MP3QuranCatalog.defaultReciterID.rawValue == "mp3quran.maher")

        let maher = try #require(catalog.reciter(MP3QuranCatalog.defaultReciterID))
        let fatiha = try catalog.source(for: RecordingID(collection: maher.collection.id, surahNumber: 1))
        let nas = try catalog.source(for: RecordingID(collection: maher.collection.id, surahNumber: 114))
        #expect(fatiha.url.absoluteString == "https://cdn.mp3quran.net/audio/maher-muaiqly/r1/001.mp3")
        #expect(nas.url.absoluteString == "https://cdn.mp3quran.net/audio/maher-muaiqly/r1/114.mp3")
        #expect(fatiha.isTestFixture == false)

        let mishary = try #require(catalog.reciters.first { $0.id.rawValue == "mp3quran.mishary" })
        let baqarah = try catalog.source(for: RecordingID(collection: mishary.collection.id, surahNumber: 2))
        #expect(baqarah.url.absoluteString == "https://cdn.mp3quran.net/audio/mishary-alafasy/r1/002.mp3")
    }

    @Test("Snapshot rejects a non-https server and an unknown collection does not resolve")
    func rejectsUnsafeServersAndUnknownCollections() throws {
        let bad = Data(#"{"reciters":[{"id":"mp3quran.maher","providerReciterId":1,"moshafId":1,"arabicName":"ا","englishName":"A","riwayah":"Hafs","style":"Murattal","server":"http://cdn.mp3quran.net/audio/x/"}]}"#.utf8)
        #expect(throws: MP3QuranCatalogError.invalidSnapshot("server must be an https directory URL: http://cdn.mp3quran.net/audio/x/")) {
            try MP3QuranCatalog(data: bad)
        }

        let catalog = try MP3QuranCatalog.bundled()
        let foreign = RecordingID(collection: RecordingCollectionID(provider: "mp3quran", collection: "999"),
                                   surahNumber: 1)
        #expect(throws: AudioCatalogError.recordingUnavailable(foreign)) {
            try catalog.source(for: foreign)
        }
    }
}
