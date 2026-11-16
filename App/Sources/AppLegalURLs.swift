import Foundation

/// HTTPS destinations for Settings legal rows and App Store Connect metadata.
///
/// Placeholder paths for Yehia to host (GitHub Pages recommended). Draft page content lives
/// in `docs/privacy-policy.md` and `docs/support-page.md` in this repo — publish those
/// documents to the URLs below (or update these constants if the final host differs).
enum AppLegalURLs {
    /// Privacy Policy — publish `docs/privacy-policy.md` here.
    static let privacyPolicy = URL(string: "https://yehiafahmy.github.io/QuranCarPlayer/privacy/")!

    /// Support — publish `docs/support-page.md` here.
    /// Contact email on that page: support@yehiafahmy.com
    static let support = URL(string: "https://yehiafahmy.github.io/QuranCarPlayer/support/")!
}
