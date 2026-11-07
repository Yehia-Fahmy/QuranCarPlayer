import Foundation

/// Small user preferences. List position is a UI preference, not playback progress.
public struct AppSettings: Codable, Equatable, Sendable {
    public var preferredReciter: ReciterID
    public var language: LanguagePreference
    /// Proposed default is enabled; the final policy depends on the CarPlay prototype.
    public var automaticCarPlayResume: Bool
    /// Stable surah number to anchor the surah list on return. Nil means "use the current surah".
    public var surahListAnchor: Int?

    public init(preferredReciter: ReciterID,
                language: LanguagePreference = .system,
                automaticCarPlayResume: Bool = true,
                surahListAnchor: Int? = nil) {
        self.preferredReciter = preferredReciter
        self.language = language
        self.automaticCarPlayResume = automaticCarPlayResume
        self.surahListAnchor = surahListAnchor
    }
}
