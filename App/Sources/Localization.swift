import Foundation
import QuranCarPlayerCore

/// Resolves UI strings for the app's own language setting (System / English / Arabic),
/// independent of the device language, so both the phone and CarPlay surfaces can switch
/// without relaunching.
enum L10n {
    private static var bundleCache: [ResolvedLanguage: Bundle] = [:]

    static func bundle(for language: ResolvedLanguage) -> Bundle {
        if let cached = bundleCache[language] { return cached }
        let bundle = Bundle.main.path(forResource: language.localeIdentifier, ofType: "lproj")
            .flatMap(Bundle.init(path:)) ?? .main
        bundleCache[language] = bundle
        return bundle
    }

    static func string(_ key: String, _ language: ResolvedLanguage) -> String {
        bundle(for: language).localizedString(forKey: key, value: nil, table: nil)
    }

    /// m:ss or h:mm:ss. Returns "--:--" for unknown values so no progress is fabricated.
    static func time(_ seconds: TimeInterval?, language: ResolvedLanguage) -> String {
        guard let seconds, seconds.isFinite, seconds >= 0 else { return "--:--" }
        let total = Int(seconds.rounded(.down))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        let text = h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
        // Keep digits Latin in both languages for consistent width on head units.
        return text
    }

    /// Localized, human-readable transport status for the current snapshot.
    static func status(for snapshot: PlaybackSnapshot, language: ResolvedLanguage) -> String {
        switch snapshot.transport {
        case .idle: return string("state.idle", language)
        case .loading: return string("state.loading", language)
        case .playing: return string("state.playing", language)
        case .paused: return string("state.paused", language)
        case .buffering: return string("state.buffering", language)
        case .retrying: return string("state.retrying", language)
        case .completed: return string("state.completed", language)
        case .failed(let failure): return failureMessage(failure.reason, language)
        }
    }

    static func failureMessage(_ reason: PlaybackFailureReason, _ language: ResolvedLanguage) -> String {
        switch reason {
        case .networkUnavailable: return string("error.network", language)
        case .recordingUnavailable: return string("error.unableToLoad", language)
        case .notPermitted: return string("error.notPermitted", language)
        case .unknown: return string("error.unableToLoad", language)
        }
    }
}
