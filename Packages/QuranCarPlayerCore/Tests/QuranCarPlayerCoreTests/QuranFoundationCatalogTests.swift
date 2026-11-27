import Foundation
import Testing
@testable import QuranCarPlayerCore

@Suite("Quran Foundation audio")
struct QuranFoundationCatalogTests {
    @Test("All nine editions resolve complete, distinct, first-party chapter URLs")
    func chapterSources() throws {
        let catalog = QuranFoundationCatalog()
        let reciters = catalog.reciters
        #expect(reciters.map(\.collection.id.collection) == ["159", "7", "3", "10", "13", "6", "9", "2", "174"])
        var urls = Set<URL>()
        for reciter in reciters {
            #expect(reciter.collection.attribution.contains(reciter.englishName))
            #expect(reciter.collection.attribution.contains("Quran Foundation"))
            for chapter in Surah.numberRange {
                let id = RecordingID(collection: reciter.collection.id, surahNumber: chapter)
                let source = try catalog.source(for: id)
                #expect(source.id == id)
                #expect(source.url.scheme == "https")
                #expect(source.url.host == "download.quranicaudio.com")
                #expect(Int(source.url.deletingPathExtension().lastPathComponent) == chapter)
                urls.insert(source.url)
            }
        }
        #expect(urls.count == 1_026)
        let old = RecordingID(collection: RecordingCollectionID(provider: "mp3quran", collection: "102"), surahNumber: 1)
        #expect(throws: AudioCatalogError.recordingUnavailable(old)) { try catalog.source(for: old) }
    }

    @Test("Expiry physically removes only old Foundation files and uses download completion time")
    func timeLimitedDeviceCopies() throws {
        let manager = FileManager.default
        let directory = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? manager.removeItem(at: directory) }
        let store = try AudioDownloadFileStore(rootDirectory: directory)
        let foundation = QuranFoundationCatalog().reciters[0].collection.id
        let expired = RecordingID(collection: foundation, surahNumber: 1)
        let fresh = RecordingID(collection: foundation, surahNumber: 2)
        let legacy = RecordingID(collection: .init(provider: "mp3quran", collection: "102"), surahNumber: 1)
        let oldDate = Date(timeIntervalSinceNow: -8 * 24 * 60 * 60)
        for recording in [expired, fresh, legacy] {
            let staging = directory.appendingPathComponent(UUID().uuidString)
            try Data([1, 2, 3]).write(to: staging)
            try manager.setAttributes([.modificationDate: oldDate], ofItemAtPath: staging.path)
            try store.installDownloadedFile(at: staging, for: recording)
        }

        let expiredURL = try #require(store.localURL(for: expired))
        try manager.setAttributes([.modificationDate: oldDate], ofItemAtPath: expiredURL.path)
        let reopened = try AudioDownloadFileStore(rootDirectory: directory)
        #expect(!manager.fileExists(atPath: expiredURL.path))
        #expect(reopened.storedRecordings() == [fresh, legacy])
        let deadline = try #require(reopened.purgeExpiredFoundationDownloads())
        #expect(abs(deadline.timeIntervalSinceNow - 7 * 24 * 60 * 60) < 10)
        let freshURL = try #require(reopened.localURL(for: fresh))
        try manager.setAttributes([.modificationDate: oldDate], ofItemAtPath: freshURL.path)
        #expect(reopened.localURL(for: fresh) == nil)
        #expect(!manager.fileExists(atPath: freshURL.path))
        #expect(reopened.localURL(for: legacy) != nil)
        #expect(reopened.storageSummary() == DownloadStorageSummary(fileCount: 1, byteCount: 3))
        #expect(reopened.purgeExpiredFoundationDownloads() == nil)
    }
}
