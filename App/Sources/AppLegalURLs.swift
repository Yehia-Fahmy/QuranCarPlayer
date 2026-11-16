import Foundation

/// HTTPS destinations for Settings legal rows and App Store Connect metadata.
///
/// Served by GitHub Pages from `docs/privacy/index.html` and `docs/support/index.html`
/// (source drafts: `docs/privacy-policy.md`, `docs/support-page.md`).
enum AppLegalURLs {
    /// Privacy Policy — `docs/privacy/index.html` on GitHub Pages.
    static let privacyPolicy = URL(string: "https://yehiafahmy.github.io/QuranCarPlayer/privacy/")!

    /// Support — `docs/support/index.html` on GitHub Pages.
    /// Contact email on that page: support@yehiafahmy.com
    static let support = URL(string: "https://yehiafahmy.github.io/QuranCarPlayer/support/")!
}
