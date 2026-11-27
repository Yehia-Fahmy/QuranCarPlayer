import Foundation
import Testing
@testable import QuranCarPlayerCore

@Suite("Provider upgrade")
@MainActor
struct ProviderUpgradeTests {
    @Test("Resume only carries a timestamp into the original downloaded performance",
          arguments: [true, false])
    func checkpointUpgrade(hasLegacyDownload: Bool) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let oldStore = try AudioDownloadFileStore(rootDirectory: root)
        let oldCatalog = try MP3QuranCatalog.bundled()
        let reciterID = MP3QuranCatalog.defaultReciterID
        let oldReciter = try #require(oldCatalog.reciter(reciterID))
        let oldRecording = RecordingID(collection: oldReciter.collection.id, surahNumber: 18)
        if hasLegacyDownload {
            let incoming = root.appendingPathComponent("incoming.mp3")
            try Data("original performance".utf8).write(to: incoming)
            try oldStore.installDownloadedFile(at: incoming, for: oldRecording)
        }
        let sessionStore = FileSessionStore(fileURL: root.appendingPathComponent("session.json"))
        let session = PlaybackSession(recording: oldRecording, elapsedSeconds: 40,
                                      checkpointDate: Date(), lastPauseReason: .user)
        try sessionStore.save(SessionCheckpoint(session: session))

        let current = QuranFoundationCatalog()
        let newReciter = try #require(current.reciter(reciterID))
        let currentRecording = RecordingID(collection: newReciter.collection.id, surahNumber: 18)
        #expect(currentRecording != oldRecording)
        let catalog = CatalogWithLegacyDownloads(current: current, legacy: oldCatalog)
        #expect(throws: AudioCatalogError.self) { try catalog.source(for: oldRecording) }
        let store = try AudioDownloadFileStore(rootDirectory: root)
        let downloads = AudioDownloadManager(catalog: catalog, store: store)
        #expect(!downloads.canDownload(oldRecording))
        let expectedRecordings: [RecordingID] = hasLegacyDownload ? [oldRecording] : []
        #expect(downloads.downloadItems.map(\.recording) == expectedRecordings)

        let engine = FakeAudioEngine()
        let coordinator = PlaybackCoordinator(surahCatalog: try SurahCatalog.bundled(), audioCatalog: catalog,
                                              engine: engine, scheduler: ManualScheduler(), sessionStore: sessionStore,
                                              settingsStore: InMemorySettingsStore(), defaultReciter: reciterID,
                                              downloadedAudioResolver: store)
        let expected = hasLegacyDownload ? oldRecording : currentRecording
        let position: TimeInterval = hasLegacyDownload ? 40 : 0
        #expect(coordinator.snapshot.currentRecording == expected)
        #expect(coordinator.snapshot.elapsed == position)
        #expect(engine.loadedItems.isEmpty)
        coordinator.continueListening()
        #expect(engine.currentItem?.startAt == position)
        #expect(engine.currentItem?.url.isFileURL == hasLegacyDownload)
        #expect(coordinator.currentReciter?.id == reciterID)

        // All chapter entry points, including CarPlay and natural continuation, use the
        // old edition only for chapters the listener actually saved.
        coordinator.selectSurah(18)
        #expect(coordinator.snapshot.currentRecording == expected)
        engine.finishCurrent()
        #expect(coordinator.snapshot.currentRecording == RecordingID(collection: currentRecording.collection, surahNumber: 19))
        coordinator.previous()
        #expect(coordinator.snapshot.currentRecording == expected)
        if hasLegacyDownload {
            engine.becomeReady()
            engine.tick(to: 13)
            engine.failCurrent(.missingRecording)
            #expect(coordinator.snapshot.currentRecording == currentRecording)
            #expect(engine.currentItem?.startAt == 0)
            #expect(engine.currentItem?.url.isFileURL == false)
        }
    }
}
