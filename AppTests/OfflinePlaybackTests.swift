import Foundation
import QuranCarPlayerCore
import Testing
@testable import QuranCarPlayer

@MainActor
struct OfflinePlaybackTests {
    @Test("AVPlayer plays a build 5 MP3Quran download from the Foundation chapter list")
    func playSavedChapter() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let catalog = AppEnvironment.shared.coordinator.audioCatalog
        let reciter = try #require(catalog.reciter(MP3QuranCatalog.defaultReciterID))
        let recording = RecordingID(collection: RecordingCollectionID(provider: "mp3quran", collection: "102"),
                                    surahNumber: 114)
        #expect(reciter.collection.id != recording.collection)
        #expect(throws: AudioCatalogError.self) { try catalog.source(for: recording) }
        // 160 silent MPEG-1 Layer III frames give AVPlayer four seconds of valid media.
        let frame = Data([0xFF, 0xFB, 0x90, 0x64]) + Data(repeating: 0, count: 413)
        var audio = Data()
        for _ in 0..<160 { audio.append(frame) }
        // This is the exact on-disk collection directory used in build 5 for Maher's moshaf 102.
        let oldDirectory = root.appendingPathComponent("eyJjb2xsZWN0aW9uIjoiMTAyIiwicHJvdmlkZXIiOiJtcDNxdXJhbiJ9")
        try FileManager.default.createDirectory(at: oldDirectory, withIntermediateDirectories: true)
        try audio.write(to: oldDirectory.appendingPathComponent("114.mp3"))

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
