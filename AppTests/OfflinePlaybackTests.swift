import Foundation
import QuranCarPlayerCore
import Testing
@testable import QuranCarPlayer

@MainActor
struct OfflinePlaybackTests {
    @Test("AVPlayer plays both generations of saved recordings under the restored catalog",
          arguments: [MP3QuranCatalog.providerKey, QuranFoundationCatalog.providerKey])
    func playSavedChapter(provider: String) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let catalog = AppEnvironment.shared.coordinator.audioCatalog
        let reciter = try #require(catalog.reciter(MP3QuranCatalog.defaultReciterID))
        // 160 silent MPEG-1 Layer III frames give AVPlayer four seconds of valid media.
        let frame = Data([0xFF, 0xFB, 0x90, 0x64]) + Data(repeating: 0, count: 413)
        var audio = Data()
        for _ in 0..<160 { audio.append(frame) }
        let recording: RecordingID
        let store: AudioDownloadFileStore
        if provider == MP3QuranCatalog.providerKey {
            recording = RecordingID(collection: reciter.collection.id, surahNumber: 114)
            #expect(try catalog.source(for: recording).url.host == "cdn.mp3quran.net")
            // Exact on-disk directory used in build 5 for Maher's moshaf 102.
            let oldDirectory = root.appendingPathComponent("eyJjb2xsZWN0aW9uIjoiMTAyIiwicHJvdmlkZXIiOiJtcDNxdXJhbiJ9")
            try FileManager.default.createDirectory(at: oldDirectory, withIntermediateDirectories: true)
            try audio.write(to: oldDirectory.appendingPathComponent("114.mp3"))
            store = try AudioDownloadFileStore(rootDirectory: root)
        } else {
            let build6Edition = try #require(catalog.legacyCollection(for: reciter.id))
            recording = RecordingID(collection: build6Edition, surahNumber: 114)
            #expect(throws: AudioCatalogError.self) { try catalog.source(for: recording) }
            store = try AudioDownloadFileStore(rootDirectory: root)
            let incoming = root.appendingPathComponent("incoming.mp3")
            try audio.write(to: incoming)
            try store.installDownloadedFile(at: incoming, for: recording)
        }

        let engine = AVPlayerEngine()
        defer { engine.stop() }
        let coordinator = PlaybackCoordinator(surahCatalog: try SurahCatalog.bundled(),
                                              audioCatalog: catalog,
                                              engine: engine,
                                              scheduler: DispatchWorkScheduler(),
                                              sessionStore: InMemorySessionStore(),
                                              settingsStore: InMemorySettingsStore(),
                                              defaultReciter: reciter.id,
                                              downloadedAudioResolver: store)
        if provider == MP3QuranCatalog.providerKey {
            coordinator.selectSurah(recording.surahNumber)
        } else {
            coordinator.playDownloadedRecording(recording)
        }
        let deadline = ContinuousClock.now + .seconds(10)
        while coordinator.snapshot.elapsed <= 0 && ContinuousClock.now < deadline {
            if case .failed = coordinator.snapshot.transport { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(coordinator.snapshot.currentRecording == recording)
        #expect(coordinator.snapshot.elapsed > 0)
    }
}
