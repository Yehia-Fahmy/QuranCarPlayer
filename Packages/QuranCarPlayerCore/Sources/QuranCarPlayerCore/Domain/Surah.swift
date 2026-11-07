import Foundation

/// One of the 114 surahs, identified by its canonical Quran-order number.
public struct Surah: Identifiable, Hashable, Codable, Sendable {
    public static let count = 114
    public static let numberRange = 1...count

    /// Canonical surah number, 1...114.
    public let number: Int
    /// Arabic name, e.g. "الفاتحة".
    public let arabicName: String
    /// Latin transliteration, e.g. "Al-Fatihah".
    public let transliteratedName: String
    /// Short English meaning, e.g. "The Opening".
    public let englishMeaning: String

    public var id: Int { number }

    public init(number: Int, arabicName: String, transliteratedName: String, englishMeaning: String) {
        self.number = number
        self.arabicName = arabicName
        self.transliteratedName = transliteratedName
        self.englishMeaning = englishMeaning
    }

    public var isFirst: Bool { number == Surah.numberRange.lowerBound }
    public var isLast: Bool { number == Surah.numberRange.upperBound }

    /// Primary display name for the resolved language.
    public func displayName(for language: ResolvedLanguage) -> String {
        switch language {
        case .arabic: return arabicName
        case .english: return transliteratedName
        }
    }

    /// Secondary line for the resolved language (meaning in English, transliteration in Arabic).
    public func secondaryName(for language: ResolvedLanguage) -> String {
        switch language {
        case .arabic: return transliteratedName
        case .english: return englishMeaning
        }
    }
}
