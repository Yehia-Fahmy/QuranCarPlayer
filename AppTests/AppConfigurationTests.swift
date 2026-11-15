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

    @Test("Composition root streams the four MP3Quran reciters, with Maher selected")
    @MainActor
    func environmentComposes() throws {
        let environment = AppEnvironment.shared
        #expect(environment.coordinator === AppEnvironment.shared.coordinator)
        #expect(environment.coordinator.surahCatalog.surahs.count == 114)
        let reciters = environment.coordinator.audioCatalog.reciters
        #expect(reciters.map(\.id.rawValue) == [
            "mp3quran.maher", "mp3quran.mishary", "mp3quran.sudais", "mp3quran.shuraim",
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
        #expect(provider.sourceKind(for: ReciterID("mp3quran.mishary")) == .typographyFallback)
        #expect(provider.sourceKind(for: ReciterID("fixture.toneA")) == .typographyFallback)
        #expect(UIImage(named: "ReciterMaher") != nil)
        #expect(UIImage(named: "ReciterSudais") != nil)
        #expect(UIImage(named: "ReciterShuraim") != nil)
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
    func artworkAttributionComplete() {
        #expect(ChapterArtworkProvider.attributions.map(\.id) == [
            "mp3quran.maher", "mp3quran.sudais", "mp3quran.shuraim",
        ])
        #expect(ChapterArtworkProvider.attributions.allSatisfy {
            $0.sourceURL.scheme == "https" && $0.licenseURL.scheme == "https"
        })
    }
}
