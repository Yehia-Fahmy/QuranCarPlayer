import Foundation

/// Direct chapter audio from Quran Foundation's QuranicAudio CDN. Album routes are
/// curated here; the app neither bundles a Content API response nor requires a token.
public struct QuranFoundationCatalog: AudioCatalog {
    public static let providerKey = "quran-foundation"
    public static let defaultReciterID = ReciterID("mp3quran.maher")
    public let reciters: [Reciter]

    // Person IDs predate the provider switch and also key artwork and settings.
    // Collection IDs identify performances, so they must use the new provider.
    private struct Edition {
        let person: String
        let number: Int
        let english: String
        let arabic: String
        let directory: String
        let padded: Bool

        init(_ person: String, _ number: Int, _ english: String, _ arabic: String,
             _ directory: String, padded: Bool = false) {
            self.person = person
            self.number = number
            self.english = english
            self.arabic = arabic
            self.directory = directory
            self.padded = padded
        }

        var collectionID: RecordingCollectionID {
            RecordingCollectionID(provider: QuranFoundationCatalog.providerKey, collection: String(number))
        }
    }

    private static let editions = [
        Edition("maher", 159, "Maher Al-Muaiqly", "ماهر المعيقلي",
                "quran/maher_almu3aiqly/year1440//", padded: true),
        Edition("mishary", 7, "Mishary Rashid Alafasy", "مشاري العفاسي",
                "qdc/mishari_al_afasy/murattal/"),
        Edition("sudais", 3, "Abdul Rahman Al-Sudais", "عبدالرحمن السديس",
                "qdc/abdurrahmaan_as_sudais/murattal/"),
        Edition("shuraim", 10, "Saud Al-Shuraim", "سعود الشريم",
                "qdc/saud_ash-shuraym/murattal/", padded: true),
        Edition("saad", 13, "Saad Al-Ghamdi", "سعد الغامدي",
                "quran/sa3d_al-ghaamidi/complete//", padded: true),
        Edition("hussary", 6, "Mahmoud Khalil Al-Hussary", "محمود خليل الحصري",
                "qdc/khalil_al_husary/murattal/"),
        Edition("minshawi", 9, "Mohammed Siddiq Al-Minshawi", "محمد صديق المنشاوي",
                "qdc/siddiq_minshawi/murattal/"),
        Edition("abdulbasit", 2, "Abdulbasit Abdulsamad", "عبد الباسط عبد الصمد",
                "qdc/abdul_baset/murattal/"),
        Edition("yasser", 174, "Yasser Al-Dosari", "ياسر الدوسري",
                "qdc/yasser_ad-dussary/mp3/")
    ]

    public init() {
        reciters = Self.editions.map { edition in
            let collection = RecordingCollection(id: edition.collectionID, riwayah: "Murattal",
                attribution: "\(edition.english) · Quran Foundation (QuranicAudio)", isTestFixture: false)
            return Reciter(id: ReciterID("mp3quran.\(edition.person)"), arabicName: edition.arabic,
                           englishName: edition.english, collection: collection)
        }
    }

    public func source(for recording: RecordingID) throws -> RecordingSource {
        guard let edition = Self.editions.first(where: { $0.collectionID == recording.collection }),
              Surah.numberRange.contains(recording.surahNumber) else {
            throw AudioCatalogError.recordingUnavailable(recording)
        }
        let chapter = edition.padded ? String(format: "%03d", recording.surahNumber) : String(recording.surahNumber)
        let url = URL(string: "https://download.quranicaudio.com/\(edition.directory)\(chapter).mp3")!
        return RecordingSource(id: recording, url: url, isTestFixture: false)
    }
}
