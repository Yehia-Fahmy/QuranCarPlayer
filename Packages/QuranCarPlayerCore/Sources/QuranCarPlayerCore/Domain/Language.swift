import Foundation

/// User-facing language preference. `.system` follows the phone.
public enum LanguagePreference: String, Codable, CaseIterable, Sendable {
    case system
    case english
    case arabic

    /// Resolve against the device's preferred languages.
    public func resolved(systemLanguageCodes: [String] = Locale.preferredLanguages) -> ResolvedLanguage {
        switch self {
        case .english: return .english
        case .arabic: return .arabic
        case .system:
            let first = systemLanguageCodes.first?.lowercased() ?? "en"
            return first.hasPrefix("ar") ? .arabic : .english
        }
    }
}

/// The language the UI actually renders in.
public enum ResolvedLanguage: String, Sendable {
    case english = "en"
    case arabic = "ar"

    public var isRightToLeft: Bool { self == .arabic }
    public var localeIdentifier: String { rawValue }
}
