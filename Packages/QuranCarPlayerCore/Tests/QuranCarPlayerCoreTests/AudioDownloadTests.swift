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
        #expect(store.storedRecordings() == Set([recording]))
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

    @Test("Collection path encoding is collision-free and migrates legacy downloads")
    func collectionPathEncodingAndMigration() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let firstRecording = RecordingID(
            collection: RecordingCollectionID(provider: "a:b", collection: "c"),
            surahNumber: 1
        )
        let secondRecording = RecordingID(
            collection: RecordingCollectionID(provider: "a", collection: "b:c"),
            surahNumber: 1
        )
        let first = directory.deletingLastPathComponent()
            .appendingPathComponent("collision-first-\(UUID().uuidString)")
        let second = directory.deletingLastPathComponent()
            .appendingPathComponent("collision-second-\(UUID().uuidString)")
        try Data("first".utf8).write(to: first)
        try Data("second".utf8).write(to: second)
        let store = try AudioDownloadFileStore(rootDirectory: directory)

        try store.installDownloadedFile(at: first, for: firstRecording)
        try store.installDownloadedFile(at: second, for: secondRecording)

        let firstURL = try #require(store.localURL(for: firstRecording))
        let secondURL = try #require(store.localURL(for: secondRecording))
        #expect(try Data(contentsOf: firstURL) == Data("first".utf8))
        #expect(try Data(contentsOf: secondURL) == Data("second".utf8))
        #expect(store.storedRecordings() == Set([firstRecording, secondRecording]))

        let legacyRoot = directory.deletingLastPathComponent()
            .appendingPathComponent("QuranCarPlayerLegacy-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: legacyRoot) }
        let legacyKey = Data("remote:1".utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        let legacyDirectory = legacyRoot.appendingPathComponent(legacyKey, isDirectory: true)
        try FileManager.default.createDirectory(at: legacyDirectory, withIntermediateDirectories: true)
        try Data("legacy".utf8).write(to: legacyDirectory.appendingPathComponent("018.audio"))

        let migrated = try AudioDownloadFileStore(rootDirectory: legacyRoot)
        #expect(migrated.storedRecordings() == Set([FixtureRemoteCatalog.recording]))
        let migratedURL = try #require(migrated.localURL(for: FixtureRemoteCatalog.recording))
        #expect(try Data(contentsOf: migratedURL) == Data("legacy".utf8))
    }

    @Test("Both historical JSON key orders merge with colon directories and survive relaunch")
    func stablePathsAfterMigration() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let collection = FixtureRemoteCatalog.collection.id
        let oldKeys = [
            #"{"provider":"remote","collection":"1"}"#,
            #"{"collection":"1","provider":"remote"}"#,
            "remote:1"
        ]
        for (offset, key) in oldKeys.enumerated() {
            let name = Data(key.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "")
            let directory = root.appendingPathComponent(name, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data([UInt8(offset + 1)]).write(to: directory.appendingPathComponent(String(format: "%03d.audio", offset + 1)))
        }
        let store = try AudioDownloadFileStore(rootDirectory: root)
        let reopened = try AudioDownloadFileStore(rootDirectory: root)
        for number in 1...3 {
            let recording = RecordingID(collection: collection, surahNumber: number)
            let url = try #require(store.localURL(for: recording))
            #expect(url.pathExtension == "mp3")
            #expect(try Data(contentsOf: url) == Data([UInt8(number)]))
            #expect((0..<100).allSatisfy { _ in reopened.localURL(for: recording) == url })
            try reopened.remove(recording)
            #expect(store.localURL(for: recording) == nil)
        }
        #expect(reopened.storageSummary() == .empty)
    }

    @Test("Abandoned incoming transfers are removed at startup")
    func recoverAbandonedTransfer() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try AudioDownloadFileStore(rootDirectory: root)
        try FileManager.default.createDirectory(at: store.transferDirectory, withIntermediateDirectories: true)
        let partial = store.transferDirectory.appendingPathComponent("qcp-leftover.mp3")
        try Data([1]).write(to: partial)
        _ = try AudioDownloadFileStore(rootDirectory: root)
        #expect(!FileManager.default.fileExists(atPath: partial.path))
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("QuranCarPlayerTests-\(UUID().uuidString)", isDirectory: true)
    }
}

@Suite("Audio download manager")
@MainActor
struct AudioDownloadManagerTests {
    @Test("Every bundled reciter collection is eligible for per-surah downloads")
    func bundledCatalogEligibility() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuranCarPlayerEligibility-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let catalog = try MP3QuranCatalog.bundled()
        let manager = AudioDownloadManager(
            catalog: catalog,
            store: try AudioDownloadFileStore(rootDirectory: directory),
            client: ImmediateDownloadClient(result: .failure(TestDownloadError.failed))
        )

        #expect(catalog.reciters.count == 9)
        for reciter in catalog.reciters {
            for surahNumber in [1, 114] {
                let recording = RecordingID(collection: reciter.collection.id,
                                            surahNumber: surahNumber)
                #expect(manager.canDownload(recording))
            }
        }
    }

    @Test("Inventory rebuilds from persisted files with exact per-item sizes")
    func persistentInventory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuranCarPlayerInventory-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try AudioDownloadFileStore(rootDirectory: directory)
        let recording18 = FixtureRemoteCatalog.recording
        let recording19 = RecordingID(collection: FixtureRemoteCatalog.collection.id, surahNumber: 19)
        let orphan = RecordingID(
            collection: RecordingCollectionID(provider: "retired", collection: "old-reciter"),
            surahNumber: 5
        )

        let first = directory.deletingLastPathComponent()
            .appendingPathComponent("inventory-first-\(UUID().uuidString)")
        let second = directory.deletingLastPathComponent()
            .appendingPathComponent("inventory-second-\(UUID().uuidString)")
        let third = directory.deletingLastPathComponent()
            .appendingPathComponent("inventory-third-\(UUID().uuidString)")
        try Data(repeating: 1, count: 12).write(to: first)
        try Data(repeating: 2, count: 34).write(to: second)
        try Data(repeating: 3, count: 7).write(to: third)
        try store.installDownloadedFile(at: first, for: recording18)
        try store.installDownloadedFile(at: second, for: recording19)
        try store.installDownloadedFile(at: third, for: orphan)

        let manager = AudioDownloadManager(catalog: FixtureRemoteCatalog(),
                                           store: store,
                                           client: ImmediateDownloadClient(
                                            result: .failure(TestDownloadError.failed)
                                           ))
        let items = manager.downloadItems

        #expect(items == [
            AudioDownloadItem(recording: recording18, state: .downloaded, byteCount: 12),
            AudioDownloadItem(recording: recording19, state: .downloaded, byteCount: 34),
            AudioDownloadItem(recording: orphan, state: .downloaded, byteCount: 7)
        ])
        #expect(manager.storageSummary == DownloadStorageSummary(fileCount: 3, byteCount: 53))
    }

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
        #expect(manager.downloadItems == [
            AudioDownloadItem(recording: FixtureRemoteCatalog.recording,
                              state: .failed(.network),
                              byteCount: nil)
        ])
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
        #expect(manager.downloadItems == [
            AudioDownloadItem(recording: FixtureRemoteCatalog.recording,
                              state: .downloading(progress: nil),
                              byteCount: nil)
        ])
        manager.cancel(FixtureRemoteCatalog.recording)
        await Task.yield()

        #expect(client.isStarted)
        #expect(manager.state(for: FixtureRemoteCatalog.recording) == .notDownloaded)
        #expect(manager.downloadItems.isEmpty)
        #expect(store.localURL(for: FixtureRemoteCatalog.recording) == nil)
    }

    @Test("Only two transfers run and cancelling a queued recording never starts it")
    func limitsConcurrentTransfers() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let client = SuspendedDownloadClient()
        let store = try AudioDownloadFileStore(rootDirectory: directory)
        let manager = AudioDownloadManager(catalog: FixtureRemoteCatalog(), store: store, client: client)
        let recordings = (1...4).map { RecordingID(collection: FixtureRemoteCatalog.collection.id, surahNumber: $0) }
        for recording in recordings { manager.download(recording) }
        await waitUntil { client.startCount == 2 }
        #expect(client.startCount == 2)
        manager.cancel(recordings[2])
        manager.cancel(recordings[0])
        await waitUntil { client.startCount == 3 }
        #expect(client.startCount == 3)
        #expect(manager.state(for: recordings[2]) == .notDownloaded)
        #expect(manager.downloadItems.map(\.recording) == [recordings[1], recordings[3]])
        manager.removeAll()
    }

    private func waitUntil(_ predicate: @escaping @MainActor () -> Bool) async {
        for _ in 0..<200 where !predicate() {
            try? await Task.sleep(for: .milliseconds(5))
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
    private var starts = 0

    var startCount: Int { lock.qcpWithLock { starts } }
    var isStarted: Bool { startCount > 0 }

    func download(from url: URL,
                  progress: @escaping @Sendable (Double?) -> Void) async throws -> URL {
        lock.qcpWithLock { starts += 1 }
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

@Suite("Audio HTTP transfers")
struct AudioDownloadClientTests {
    @Test("A complete decodable recording is returned to the caller")
    func validAudio() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let client = makeClient(directory: directory)
        let file = try await client.download(from: URL(string: "https://example.test/valid")!) { _ in }
        #expect(try Data(contentsOf: file) == AudioResponseProtocol.mp3)
    }

    @Test("Incomplete, oversized and unplayable responses leave no file",
          arguments: ["partial", "range", "short", "declared-large", "chunked-large", "html"])
    func rejectsInvalidResponse(scenario: String) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let client = makeClient(directory: directory)
        let url = URL(string: "https://example.test/")!.appendingPathComponent(scenario)
        let expected: AudioDownloadClientError
        switch scenario {
        case "partial": expected = .httpStatus(206)
        case "declared-large", "chunked-large": expected = .tooLarge
        case "html": expected = .invalidAudio
        default: expected = .invalidResponse
        }
        await #expect(throws: expected) { try await client.download(from: url) { _ in } }
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    private func makeClient(directory: URL) -> URLSessionAudioDownloadClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AudioResponseProtocol.self]
        return URLSessionAudioDownloadClient(configuration: configuration, transferDirectory: directory, maximumBytes: 16_384)
    }
}

private final class AudioResponseProtocol: URLProtocol, @unchecked Sendable {
    // 24 silent MPEG-1 Layer III frames at 128 kbps, 44.1 kHz (about 0.627 seconds).
    static let mp3: Data = {
        let frame = Data([0xFF, 0xFB, 0x90, 0x64]) + Data(repeating: 0, count: 413)
        return (0..<24).reduce(into: Data()) { output, _ in output.append(frame) }
    }()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url!
        let scenario = url.lastPathComponent
        var data = Self.mp3
        var headers = ["Content-Type": "audio/mpeg"]
        switch scenario {
        case "range": headers["Content-Range"] = "bytes 0-10007/20016"
        case "short": headers["Content-Length"] = String(data.count + 1)
        case "declared-large": headers["Content-Length"] = "32768"
        case "chunked-large": data = Data(repeating: 1, count: 16_385)
        case "html": data = Data("<html>Temporarily unavailable</html>".utf8)
        default: headers["Content-Length"] = String(data.count)
        }
        let response = HTTPURLResponse(url: url, statusCode: scenario == "partial" ? 206 : 200,
                                       httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
