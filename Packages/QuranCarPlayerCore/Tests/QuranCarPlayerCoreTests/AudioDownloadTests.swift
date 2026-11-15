import Foundation
import Testing
@testable import QuranCarPlayerCore

@Suite("Offline audio storage")
struct AudioDownloadFileStoreTests {
    @Test("Completed files persist, resolve by exact recording, and can be removed")
    func installResolveRemove() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try AudioDownloadFileStore(rootDirectory: directory)
        let recording = Fixtures.recording(18)
        let downloaded = directory.deletingLastPathComponent()
            .appendingPathComponent("download-\(UUID().uuidString)")
        try Data("audio bytes".utf8).write(to: downloaded)

        try store.installDownloadedFile(at: downloaded, for: recording)

        let localURL = try #require(store.localURL(for: recording))
        #expect(try Data(contentsOf: localURL) == Data("audio bytes".utf8))
        #expect(store.localURL(for: Fixtures.recording(19)) == nil)
        #expect(store.storageSummary() == DownloadStorageSummary(fileCount: 1, byteCount: 11))

        try store.remove(recording)
        #expect(store.localURL(for: recording) == nil)
        #expect(store.storageSummary() == .empty)
    }

    @Test("Incomplete and empty files are never exposed as playable")
    func incompleteFilesAreCleaned() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let incomplete = directory.appendingPathComponent(".orphan.download")
        try Data("partial".utf8).write(to: incomplete)

        let store = try AudioDownloadFileStore(rootDirectory: directory)
        #expect(!FileManager.default.fileExists(atPath: incomplete.path))

        let empty = directory.deletingLastPathComponent()
            .appendingPathComponent("empty-\(UUID().uuidString)")
        #expect(FileManager.default.createFile(atPath: empty.path, contents: Data()))
        #expect(throws: AudioDownloadFileStoreError.invalidDownloadedFile) {
            try store.installDownloadedFile(at: empty, for: Fixtures.recording(1))
        }
        #expect(store.localURL(for: Fixtures.recording(1)) == nil)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("QuranCarPlayerTests-\(UUID().uuidString)", isDirectory: true)
    }
}

@Suite("Audio download manager")
@MainActor
struct AudioDownloadManagerTests {
    @Test("Successful downloads publish progress and become persistent")
    func successfulDownload() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuranCarPlayerManagerTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try AudioDownloadFileStore(rootDirectory: directory)
        let temporary = directory.deletingLastPathComponent()
            .appendingPathComponent("manager-download-\(UUID().uuidString)")
        try Data("downloaded audio".utf8).write(to: temporary)
        let manager = AudioDownloadManager(catalog: FixtureRemoteCatalog(),
                                           store: store,
                                           client: ImmediateDownloadClient(result: .success(temporary)))
        let recording = FixtureRemoteCatalog.recording

        manager.download(recording)
        await waitUntil { manager.state(for: recording) == .downloaded }

        #expect(manager.state(for: recording) == .downloaded)
        #expect(store.localURL(for: recording) != nil)
        #expect(manager.storageSummary.fileCount == 1)
    }

    @Test("Failures are retryable and never create a local recording")
    func failedDownload() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuranCarPlayerManagerFailure-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try AudioDownloadFileStore(rootDirectory: directory)
        let manager = AudioDownloadManager(catalog: FixtureRemoteCatalog(),
                                           store: store,
                                           client: ImmediateDownloadClient(result: .failure(TestDownloadError.failed)))

        manager.download(FixtureRemoteCatalog.recording)
        await waitUntil {
            manager.state(for: FixtureRemoteCatalog.recording) == .failed(.network)
        }

        #expect(store.localURL(for: FixtureRemoteCatalog.recording) == nil)
        #expect(manager.storageSummary == .empty)
    }

    @Test("Cancellation returns to streaming state without installing a file")
    func cancellation() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuranCarPlayerManagerCancel-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try AudioDownloadFileStore(rootDirectory: directory)
        let client = SuspendedDownloadClient()
        let manager = AudioDownloadManager(catalog: FixtureRemoteCatalog(),
                                           store: store,
                                           client: client)

        manager.download(FixtureRemoteCatalog.recording)
        await waitUntil { client.isStarted }
        manager.cancel(FixtureRemoteCatalog.recording)
        await Task.yield()

        #expect(client.isStarted)
        #expect(manager.state(for: FixtureRemoteCatalog.recording) == .notDownloaded)
        #expect(store.localURL(for: FixtureRemoteCatalog.recording) == nil)
    }

    private func waitUntil(_ predicate: @escaping @MainActor () -> Bool) async {
        for _ in 0..<100 where !predicate() {
            await Task.yield()
        }
    }
}

private enum TestDownloadError: Error {
    case failed
}

private struct ImmediateDownloadClient: AudioDownloadClient {
    let result: Result<URL, Error>

    func download(from url: URL,
                  progress: @escaping @Sendable (Double?) -> Void) async throws -> URL {
        progress(0.5)
        try Task.checkCancellation()
        return try result.get()
    }
}

private final class SuspendedDownloadClient: AudioDownloadClient, @unchecked Sendable {
    private let lock = NSLock()
    private var started = false

    var isStarted: Bool {
        lock.qcpWithLock { started }
    }

    func download(from url: URL,
                  progress: @escaping @Sendable (Double?) -> Void) async throws -> URL {
        lock.qcpWithLock { started = true }
        progress(nil)
        try await Task.sleep(nanoseconds: 60_000_000_000)
        throw TestDownloadError.failed
    }
}

private struct FixtureRemoteCatalog: AudioCatalog {
    static let collection = RecordingCollection(
        id: RecordingCollectionID(provider: "remote", collection: "1"),
        riwayah: "test",
        attribution: "test",
        isTestFixture: false
    )
    static let recording = RecordingID(collection: collection.id, surahNumber: 18)

    let reciters = [
        Reciter(id: ReciterID("remote"),
                arabicName: "قارئ",
                englishName: "Reciter",
                collection: collection)
    ]

    func source(for recording: RecordingID) throws -> RecordingSource {
        guard recording.collection == Self.collection.id else {
            throw AudioCatalogError.recordingUnavailable(recording)
        }
        return RecordingSource(id: recording,
                               url: URL(string: "https://example.com/018.mp3")!,
                               isTestFixture: false)
    }
}
