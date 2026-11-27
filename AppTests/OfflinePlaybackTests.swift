import Foundation
import QuranCarPlayerCore
import Testing

@MainActor
struct OfflinePlaybackTests {
    @Test("AVPlayer advances using only a saved chapter after the store reopens")
    func playSavedChapter() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try AudioDownloadFileStore(rootDirectory: root)
        // Only the installed copy can play. The catalog's fallback file does not exist.
        let catalog = FixtureAudioCatalog(fixtureURLs: [root.appendingPathComponent("missing.mp3")])
        let reciter = try #require(catalog.reciter(FixtureAudioCatalog.defaultReciterID))
        let recording = RecordingID(collection: reciter.collection.id, surahNumber: 114)
        // 160 silent MPEG-1 Layer III frames give AVPlayer four seconds of valid media.
        let frame = Data([0xFF, 0xFB, 0x90, 0x64]) + Data(repeating: 0, count: 413)
        var audio = Data()
        for _ in 0..<160 { audio.append(frame) }
        let incoming = root.appendingPathComponent("incoming.mp3")
        try audio.write(to: incoming)
        try store.installDownloadedFile(at: incoming, for: recording)

        let engine = AVPlayerEngine()
        defer { engine.stop() }
        let coordinator = PlaybackCoordinator(surahCatalog: try SurahCatalog.bundled(),
                                              audioCatalog: catalog,
                                              engine: engine,
                                              scheduler: DispatchWorkScheduler(),
                                              sessionStore: InMemorySessionStore(),
                                              settingsStore: InMemorySettingsStore(),
                                              defaultReciter: reciter.id,
                                              downloadedAudioResolver: try AudioDownloadFileStore(rootDirectory: root))
        coordinator.selectSurah(recording.surahNumber)
        let deadline = ContinuousClock.now + .seconds(10)
        while coordinator.snapshot.elapsed <= 0 && ContinuousClock.now < deadline {
            if case .failed = coordinator.snapshot.transport { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(coordinator.snapshot.currentRecording == recording)
        #expect(coordinator.snapshot.elapsed > 0)
    }
}
