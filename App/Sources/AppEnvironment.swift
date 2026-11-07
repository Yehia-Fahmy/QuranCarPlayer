import Foundation
import QuranCarPlayerCore

/// Composition root. Wires the shared coordinator to the real AVPlayer engine,
/// audio session, and Now Playing bridge. Created once per process.
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let coordinator: PlaybackCoordinator
    let engine: AVPlayerEngine
    let nowPlaying: NowPlayingBridge
    let audioSession: AudioSessionController

    /// Names of the bundled test-tone fixtures (see Scripts/generate-test-audio.py).
    nonisolated static let fixtureNames = ["test-tone-a", "test-tone-b", "test-tone-c"]

    private init() {
        let surahCatalog: SurahCatalog
        do {
            surahCatalog = try SurahCatalog.bundled()
        } catch {
            fatalError("Bundled surah catalog is invalid: \(error)")
        }

        // UI tests pass -QCPUITestReset so each launch starts from defaults
        // and plays bundled test tones. A normal launch streams the MP3Quran
        // snapshot. A previous test's language or saved session must not leak
        // through the shared simulator container.
        let isUITest = ProcessInfo.processInfo.arguments.contains("-QCPUITestReset")
        let audioCatalog: AudioCatalog
        let defaultReciter: ReciterID
        if isUITest {
            let fixtureURLs = AppEnvironment.fixtureNames.compactMap {
                Bundle.main.url(forResource: $0, withExtension: "m4a")
            }
            guard !fixtureURLs.isEmpty else {
                fatalError("Test audio fixtures are missing from the app bundle. Run Scripts/generate-test-audio.py.")
            }
            audioCatalog = FixtureAudioCatalog(fixtureURLs: fixtureURLs)
            defaultReciter = FixtureAudioCatalog.defaultReciterID
        } else {
            do {
                let catalog = try MP3QuranCatalog.bundled()
                audioCatalog = catalog
                defaultReciter = MP3QuranCatalog.defaultReciterID
            } catch {
                fatalError("MP3Quran catalog snapshot is invalid: \(error)")
            }
        }

        let sessionStore: SessionStore
        let settingsStore: SettingsStore
        if isUITest {
            sessionStore = InMemorySessionStore()
            settingsStore = InMemorySettingsStore()
        } else {
            do {
                sessionStore = try FileSessionStore.applicationSupport()
            } catch {
                sessionStore = InMemorySessionStore()
            }
            settingsStore = UserDefaultsSettingsStore()
        }

        let engine = AVPlayerEngine()
        self.engine = engine
        coordinator = PlaybackCoordinator(surahCatalog: surahCatalog,
                                          audioCatalog: audioCatalog,
                                          engine: engine,
                                          scheduler: DispatchWorkScheduler(),
                                          sessionStore: sessionStore,
                                          settingsStore: settingsStore,
                                          defaultReciter: defaultReciter)
        nowPlaying = NowPlayingBridge(coordinator: coordinator) { language in
            NowPlayingLabels(testAudioNotice: L10n.string("testAudio.short", language))
        }
        audioSession = AudioSessionController(coordinator: coordinator, engine: engine)
    }
}
