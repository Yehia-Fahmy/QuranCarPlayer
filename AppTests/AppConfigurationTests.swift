import Foundation
import UIKit
import Testing
import QuranCarPlayerCore
@testable import QuranCarPlayer

// App-bundle smoke tests. These run in the iOS simulator via the QuranCarPlayer scheme
// (`xcodebuild test`), not via `swift test`, because they need the built app bundle.

@Suite("App bundle configuration")
struct AppConfigurationTests {
    private var bundle: Bundle { Bundle(for: CarPlaySceneDelegate.self) }

    @Test("Info.plist declares the CarPlay scene with a resolvable delegate class")
    func carPlaySceneConfigured() throws {
        let manifest = try #require(bundle.object(forInfoDictionaryKey: "UIApplicationSceneManifest") as? [String: Any])
        #expect(manifest["UIApplicationSupportsMultipleScenes"] as? Bool == true)
        let configs = try #require(manifest["UISceneConfigurations"] as? [String: Any])
        let carPlay = try #require(configs["CPTemplateApplicationSceneSessionRoleApplication"] as? [[String: Any]])
        let first = try #require(carPlay.first)
        #expect(first["UISceneClassName"] as? String == "CPTemplateApplicationScene")
        let delegateName = try #require(first["UISceneDelegateClassName"] as? String)
        #expect(NSClassFromString(delegateName) != nil, "delegate class \(delegateName) must resolve at runtime")
    }

    @Test("Background audio mode is declared")
    func backgroundAudio() throws {
        let modes = try #require(bundle.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String])
        #expect(modes.contains("audio"))
    }

    @Test("Display name and marketing version match the 1.0 store candidate")
    func displayNameAndVersion() throws {
        #expect(bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String == "Quran CarPlayer")
        #expect(bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == "1.0.0")
        let build = try #require(bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
        #expect((Int(build) ?? 0) >= 3)
    }

    @Test("Privacy manifest declares UserDefaults CA92.1 only")
    func privacyManifestPresent() throws {
        let url = try #require(bundle.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let data = try Data(contentsOf: url)
        let plist = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        #expect(plist["NSPrivacyTracking"] as? Bool == false)
        let accessed = try #require(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        #expect(accessed.count == 1)
        let entry = try #require(accessed.first)
        #expect(entry["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults")
        #expect(entry["NSPrivacyAccessedAPITypeReasons"] as? [String] == ["CA92.1"])
    }

    @Test("Settings legal URLs are HTTPS placeholders Yehia can host")
    func legalURLsConfigured() {
        #expect(AppLegalURLs.privacyPolicy.scheme == "https")
        #expect(AppLegalURLs.support.scheme == "https")
        #expect(AppLegalURLs.privacyPolicy.host == "yehia-fahmy.github.io")
        #expect(AppLegalURLs.support.host == "yehia-fahmy.github.io")
        #expect(AppLegalURLs.privacyPolicy.path.contains("privacy"))
        #expect(AppLegalURLs.support.path.contains("support"))
        #expect(L10n.string("settings.privacyPolicy", .english) == "Privacy Policy")
        #expect(L10n.string("settings.support", .english) == "Support")
        #expect(L10n.string("settings.privacyPolicy", .arabic) == "سياسة الخصوصية")
        #expect(L10n.string("settings.support", .arabic) == "الدعم")
        #expect(L10n.string("surahs.current", .english) == "Current Surah")
        #expect(L10n.string("app.title", .english) == "Quran CarPlayer")
    }

    @Test("App icon catalog merges into the bundle so CarPlay can resolve both scales")
    func appIconEmbeddedForCarPlay() throws {
        // actool merges CFBundleIcons from the AppIcon set into the processed
        // Info.plist. If this dictionary is missing, CarPlay/SpringBoard fall back
        // to stale cached icons and the large home-grid glyph can disagree with
        // the small sidebar glyph.
        let icons = try #require(bundle.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any])
        let primary = try #require(icons["CFBundlePrimaryIcon"] as? [String: Any])
        #expect(primary["CFBundleIconName"] as? String == "AppIcon")
        let files = try #require(primary["CFBundleIconFiles"] as? [String])
        #expect(files.contains("AppIcon60x60"))

        // Loose PNG emitted beside Assets.car for the phone primary icon.
        let iconURL = try #require(bundle.url(forResource: "AppIcon60x60@2x", withExtension: "png"))
        let size = try #require(try FileManager.default.attributesOfItem(atPath: iconURL.path)[.size] as? Int)
        #expect(size > 1000)

        // CarPlay 60pt @2x/@3x slots live in Assets.car; the catalog source files
        // must exist in the app resources tree used to build that car.
        let catalog = try #require(bundle.url(forResource: "Assets", withExtension: "car"))
        let catalogSize = try #require(
            try FileManager.default.attributesOfItem(atPath: catalog.path)[.size] as? Int
        )
        #expect(catalogSize > 100_000, "Assets.car should include AppIcon + artwork, not AccentColor alone")
    }

    @Test("Test-tone fixtures are bundled and non-empty")
    func fixturesBundled() throws {
        for name in AppEnvironment.fixtureNames {
            let url = try #require(bundle.url(forResource: name, withExtension: "m4a"), "missing \(name).m4a")
            let size = try #require(try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int)
            #expect(size > 1000)
        }
    }

    @Test("English and Arabic localizations resolve different strings")
    func localizations() {
        let en = L10n.string("surahs.title", .english)
        let ar = L10n.string("surahs.title", .arabic)
        #expect(en == "Surahs")
        #expect(ar == "السور")
        #expect(L10n.time(nil, language: .english) == "--:--")
        #expect(L10n.time(3725, language: .english) == "1:02:05")
        #expect(L10n.time(65, language: .arabic) == "1:05")
        #expect(L10n.string("downloads.manage", .english) == "Manage Downloads")
        #expect(L10n.string("downloads.manage", .arabic) == "إدارة التنزيلات")
        #expect(L10n.string("downloads.empty.title", .english) == "No Downloads")
        #expect(L10n.string("downloads.empty.title", .arabic) == "لا توجد تنزيلات")
    }

    @Test("Composition root streams nine MP3Quran reciters, with Maher selected")
    @MainActor
    func environmentComposes() throws {
        let environment = AppEnvironment.shared
        #expect(environment.coordinator === AppEnvironment.shared.coordinator)
        #expect(environment.coordinator.surahCatalog.surahs.count == 114)
        let reciters = environment.coordinator.audioCatalog.reciters
        #expect(reciters.map(\.id.rawValue) == [
            "mp3quran.maher", "mp3quran.mishary", "mp3quran.sudais", "mp3quran.shuraim",
            "mp3quran.saad", "mp3quran.hussary", "mp3quran.minshawi",
            "mp3quran.abdulbasit", "mp3quran.yasser",
        ])
        #expect(reciters.allSatisfy { $0.collection.isTestFixture == false })
        #expect(environment.coordinator.selectedReciter?.englishName == "Maher Al-Muaiqly")
    }

    @Test("Cleared reciters use portraits while Mishary and fixtures use typography")
    @MainActor
    func artworkSourcePolicy() throws {
        let provider = ChapterArtworkProvider()
        #expect(provider.sourceKind(for: ReciterID("mp3quran.maher")) == .licensedPortrait)
        #expect(provider.sourceKind(for: ReciterID("mp3quran.sudais")) == .licensedPortrait)
        #expect(provider.sourceKind(for: ReciterID("mp3quran.shuraim")) == .licensedPortrait)
        #expect(provider.sourceKind(for: ReciterID("mp3quran.saad")) == .licensedPortrait)
        #expect(provider.sourceKind(for: ReciterID("mp3quran.hussary")) == .licensedPortrait)
        #expect(provider.sourceKind(for: ReciterID("mp3quran.minshawi")) == .licensedPortrait)
        #expect(provider.sourceKind(for: ReciterID("mp3quran.abdulbasit")) == .licensedPortrait)
        #expect(provider.sourceKind(for: ReciterID("mp3quran.yasser")) == .licensedPortrait)
        #expect(provider.sourceKind(for: ReciterID("mp3quran.mishary")) == .typographyFallback)
        #expect(provider.sourceKind(for: ReciterID("fixture.toneA")) == .typographyFallback)
        #expect(UIImage(named: "ReciterMaher") != nil)
        #expect(UIImage(named: "ReciterSudais") != nil)
        #expect(UIImage(named: "ReciterShuraim") != nil)
        #expect(UIImage(named: "ReciterSaad") != nil)
        #expect(UIImage(named: "ReciterHussary") != nil)
        #expect(UIImage(named: "ReciterMinshawi") != nil)
        #expect(UIImage(named: "ReciterAbdulbasit") != nil)
        #expect(UIImage(named: "ReciterYasser") != nil)
        #expect(UIImage(named: "ReciterMishary") == nil)
    }

    @Test("Artwork renders offline at list and Now Playing sizes")
    @MainActor
    func artworkRenders() throws {
        let environment = AppEnvironment.shared
        let surah = try #require(environment.coordinator.surahCatalog.surah(74))
        let reciters = environment.coordinator.audioCatalog.reciters
        let maher = try #require(reciters.first { $0.id == ReciterID("mp3quran.maher") })
        let mishary = try #require(reciters.first { $0.id == ReciterID("mp3quran.mishary") })

        let portrait = environment.artworkProvider.image(
            for: surah,
            reciter: maher,
            language: .english,
            size: CGSize(width: 96, height: 96)
        )
        let fallback = environment.artworkProvider.image(
            for: surah,
            reciter: mishary,
            language: .arabic,
            size: CGSize(width: 1_024, height: 1_024)
        )
        let portraitEnglish = environment.artworkProvider.image(
            for: surah,
            reciter: maher,
            language: .english,
            size: CGSize(width: 1_024, height: 1_024)
        )
        let portraitArabic = environment.artworkProvider.image(
            for: surah,
            reciter: maher,
            language: .arabic,
            size: CGSize(width: 1_024, height: 1_024)
        )
        #expect(portrait.size == CGSize(width: 96, height: 96))
        #expect(fallback.size == CGSize(width: 1_024, height: 1_024))
        #expect(portrait.pngData() != fallback.pngData())
        #expect(portraitEnglish.pngData() != portraitArabic.pngData())
        for reciterID in [
            "mp3quran.saad", "mp3quran.hussary", "mp3quran.minshawi",
            "mp3quran.abdulbasit", "mp3quran.yasser",
        ] {
            let reciter = try #require(reciters.first { $0.id == ReciterID(reciterID) })
            let generated = environment.artworkProvider.image(
                for: surah,
                reciter: reciter,
                language: .english,
                size: CGSize(width: 1_024, height: 1_024)
            )
            #expect(generated.size == CGSize(width: 1_024, height: 1_024))
            #expect(generated.pngData() != fallback.pngData())
        }

        let nowPlaying = environment.artworkProvider.nowPlayingArtwork(
            for: surah,
            reciter: maher,
            language: .english
        )
        #expect(nowPlaying.bounds.size == CGSize(width: 1_024, height: 1_024))
        let commonSize = try #require(nowPlaying.image(at: CGSize(width: 256, height: 256)))
        let customSize = try #require(nowPlaying.image(at: CGSize(width: 300, height: 300)))
        #expect(commonSize.size == CGSize(width: 256, height: 256))
        #expect(customSize.size == CGSize(width: 300, height: 300))
    }

    @Test("Every bundled portrait has a source and license record")
    @MainActor
    func artworkAttributionComplete() throws {
        #expect(ChapterArtworkProvider.attributions.map(\.id) == [
            "mp3quran.maher", "mp3quran.sudais", "mp3quran.shuraim",
            "mp3quran.saad", "mp3quran.hussary", "mp3quran.minshawi",
            "mp3quran.abdulbasit", "mp3quran.yasser",
        ])
        #expect(ChapterArtworkProvider.attributions.allSatisfy {
            $0.sourceURL.scheme == "https" && $0.licenseURL.scheme == "https"
        })
        let maher = try #require(ChapterArtworkProvider.attributions.first {
            $0.id == "mp3quran.maher"
        })
        #expect(maher.detail.contains("Real avdulmouhd"))
        #expect(maher.sourceURL.absoluteString ==
                "https://commons.wikimedia.org/wiki/File:Professor_Maher_Al-Mu%27aiqly.jpg")
        #expect(maher.licenseURL.absoluteString ==
                "https://creativecommons.org/licenses/by-sa/4.0/")
    }
}
