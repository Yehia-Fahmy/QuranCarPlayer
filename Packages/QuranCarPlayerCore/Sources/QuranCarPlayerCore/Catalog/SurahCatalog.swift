import Foundation

public enum SurahCatalogError: Error, Equatable {
    case resourceMissing
    case wrongCount(Int)
    case nonSequentialNumbers
    case emptyName(Int)
}

/// Bundled canonical surah metadata so browsing never requires live catalog access.
public struct SurahCatalog: Sendable {
    public let surahs: [Surah]

    /// Loads and validates the bundled `surahs.json`.
    public static func bundled() throws -> SurahCatalog {
        guard let url = Bundle.module.url(forResource: "surahs", withExtension: "json") else {
            throw SurahCatalogError.resourceMissing
        }
        return try SurahCatalog(data: Data(contentsOf: url))
    }

    public init(data: Data) throws {
        struct Row: Decodable {
            let number: Int
            let arabic: String
            let transliteration: String
            let meaning: String
        }
        let rows = try JSONDecoder().decode([Row].self, from: data)
        try self.init(surahs: rows.map {
            Surah(number: $0.number, arabicName: $0.arabic, transliteratedName: $0.transliteration, englishMeaning: $0.meaning)
        })
    }

    /// Validates exactly 114 surahs numbered 1...114 in order with non-empty names.
    public init(surahs: [Surah]) throws {
        guard surahs.count == Surah.count else { throw SurahCatalogError.wrongCount(surahs.count) }
        for (index, surah) in surahs.enumerated() {
            guard surah.number == index + 1 else { throw SurahCatalogError.nonSequentialNumbers }
            guard !surah.arabicName.isEmpty, !surah.transliteratedName.isEmpty, !surah.englishMeaning.isEmpty else {
                throw SurahCatalogError.emptyName(surah.number)
            }
        }
        self.surahs = surahs
    }

    public func surah(_ number: Int) -> Surah? {
        guard Surah.numberRange.contains(number) else { return nil }
        return surahs[number - 1]
    }
}
