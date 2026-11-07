import Foundation
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
}
