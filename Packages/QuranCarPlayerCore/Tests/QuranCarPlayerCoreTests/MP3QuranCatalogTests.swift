import Foundation
import Testing
@testable import QuranCarPlayerCore

@Suite("MP3Quran catalog")
struct MP3QuranCatalogTests {
    @Test("Bundled snapshot streams nine complete Hafs collections")
    func bundledReciters() throws {
        let catalog = try MP3QuranCatalog.bundled()
        #expect(catalog.reciters.map(\.englishName) == [
            "Maher Al-Muaiqly",
            "Mishary Rashid Alafasy",
            "Abdul Rahman Al-Sudais",
            "Saud Al-Shuraim",
            "Saad Al-Ghamdi",
            "Mahmoud Khalil Al-Hussary",
            "Mohammed Siddiq Al-Minshawi",
            "Abdulbasit Abdulsamad",
            "Yasser Al-Dosari",
        ])
        #expect(catalog.reciters.map(\.arabicName) == [
            "ماهر المعيقلي",
            "مشاري العفاسي",
            "عبدالرحمن السديس",
            "سعود الشريم",
            "سعد الغامدي",
            "محمود خليل الحصري",
            "محمد صديق المنشاوي",
            "عبد الباسط عبد الصمد",
            "ياسر الدوسري",
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

        let expectedNewSources = [
            "mp3quran.saad": ("30", "https://cdn.mp3quran.net/audio/saad-ghamdi/r1/114.mp3"),
            "mp3quran.hussary": ("118", "https://cdn.mp3quran.net/audio/mahmoud-husary/r1/114.mp3"),
            "mp3quran.minshawi": ("112", "https://cdn.mp3quran.net/audio/muhammad-minshawi/r1/114.mp3"),
            "mp3quran.abdulbasit": ("53", "https://cdn.mp3quran.net/audio/abdulbasit-abdulsamad/r3/114.mp3"),
            "mp3quran.yasser": ("92", "https://cdn.mp3quran.net/audio/yasser-dosari/r1/114.mp3"),
        ]
        for (reciterID, expected) in expectedNewSources {
            let reciter = try #require(catalog.reciters.first { $0.id.rawValue == reciterID })
            #expect(reciter.collection.id.collection == expected.0)
            let source = try catalog.source(for: RecordingID(collection: reciter.collection.id,
                                                              surahNumber: 114))
            #expect(source.url.absoluteString == expected.1)
        }
    }

    @Test("Snapshot rejects incomplete or unsafe collections and unknown collections do not resolve")
    func rejectsUnsafeServersAndUnknownCollections() throws {
        let complete = Array(1...114)
        let bad = try JSONSerialization.data(withJSONObject: [
            "reciters": [[
                "id": "mp3quran.maher",
                "providerReciterId": 1,
                "moshafId": 1,
                "arabicName": "ا",
                "englishName": "A",
                "riwayah": "Hafs",
                "style": "Murattal",
                "server": "http://cdn.mp3quran.net/audio/x/",
                "surahNumbers": complete,
            ]],
        ])
        #expect(throws: MP3QuranCatalogError.invalidSnapshot("server must be an https directory URL: http://cdn.mp3quran.net/audio/x/")) {
            try MP3QuranCatalog(data: bad)
        }

        let incomplete = try JSONSerialization.data(withJSONObject: [
            "reciters": [[
                "id": "mp3quran.maher",
                "providerReciterId": 1,
                "moshafId": 1,
                "arabicName": "ا",
                "englishName": "A",
                "riwayah": "Hafs",
                "style": "Murattal",
                "server": "https://cdn.mp3quran.net/audio/x/",
                "surahNumbers": Array(1...113),
            ]],
        ])
        #expect(throws: MP3QuranCatalogError.invalidSnapshot("incomplete surah list for mp3quran.maher")) {
            try MP3QuranCatalog(data: incomplete)
        }

        let unsupported = try JSONSerialization.data(withJSONObject: [
            "reciters": [[
                "id": "mp3quran.maher",
                "providerReciterId": 1,
                "moshafId": 1,
                "arabicName": "ا",
                "englishName": "A",
                "riwayah": "Warsh",
                "style": "Mujawwad",
                "server": "https://cdn.mp3quran.net/audio/x/",
                "surahNumbers": complete,
            ]],
        ])
        #expect(throws: MP3QuranCatalogError.invalidSnapshot("unsupported collection type for mp3quran.maher")) {
            try MP3QuranCatalog(data: unsupported)
        }

        let duplicateCollection = try JSONSerialization.data(withJSONObject: [
            "reciters": [
                [
                    "id": "mp3quran.maher",
                    "providerReciterId": 1,
                    "moshafId": 1,
                    "arabicName": "ا",
                    "englishName": "A",
                    "riwayah": "Hafs an Asim",
                    "style": "Murattal",
                    "server": "https://cdn.mp3quran.net/audio/x/",
                    "surahNumbers": complete,
                ],
                [
                    "id": "mp3quran.other",
                    "providerReciterId": 2,
                    "moshafId": 1,
                    "arabicName": "ب",
                    "englishName": "B",
                    "riwayah": "Hafs an Asim",
                    "style": "Murattal",
                    "server": "https://cdn.mp3quran.net/audio/y/",
                    "surahNumbers": complete,
                ],
            ],
        ])
        #expect(throws: MP3QuranCatalogError.invalidSnapshot("duplicate collection 1")) {
            try MP3QuranCatalog(data: duplicateCollection)
        }

        let catalog = try MP3QuranCatalog.bundled()
        let foreign = RecordingID(collection: RecordingCollectionID(provider: "mp3quran", collection: "999"),
                                   surahNumber: 1)
        #expect(throws: AudioCatalogError.recordingUnavailable(foreign)) {
            try catalog.source(for: foreign)
        }
    }
}
