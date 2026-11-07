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

        let fixtureURLs = AppEnvironment.fixtureNames.compactMap {
            Bundle.main.url(forResource: $0, withExtension: "m4a")
        }
        guard !fixtureURLs.isEmpty else {
            fatalError("Test audio fixtures are missing from the app bundle. Run Scripts/generate-test-audio.py.")
        }
        // Production audio is blocked on provider permission (DESIGN.md §7). Until then
        // the app plays clearly-labelled synthetic test tones.
        let audioCatalog = FixtureAudioCatalog(fixtureURLs: fixtureURLs)

        // UI tests pass -QCPUITestReset so each launch starts from defaults.
        // Otherwise a previous test's Arabic setting or saved session leaks
        // through the shared simulator container.
        let sessionStore: SessionStore
        let settingsStore: SettingsStore
        if ProcessInfo.processInfo.arguments.contains("-QCPUITestReset") {
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
                                          defaultReciter: FixtureAudioCatalog.defaultReciterID)
        nowPlaying = NowPlayingBridge(coordinator: coordinator) { language in
            NowPlayingLabels(testAudioNotice: L10n.string("testAudio.short", language))
        }
        audioSession = AudioSessionController(coordinator: coordinator, engine: engine)
    }
}
