import Foundation
import Observation

public enum AudioDownloadFailure: Equatable, Sendable {
    case unavailable
    case network
    case storage
}

public enum AudioDownloadState: Equatable, Sendable {
    case notDownloaded
    case downloading(progress: Double?)
    case downloaded
    case failed(AudioDownloadFailure)
}

public struct AudioDownloadItem: Identifiable, Equatable, Sendable {
    public var id: RecordingID { recording }
    public let recording: RecordingID
    public let state: AudioDownloadState
    public let byteCount: Int64?

    public init(recording: RecordingID, state: AudioDownloadState, byteCount: Int64?) {
        self.recording = recording
        self.state = state
        self.byteCount = byteCount
    }
}

/// Coordinates user-initiated recording downloads and exposes per-recording UI state.
@Observable
@MainActor
public final class AudioDownloadManager {
    private var stateRevision = 0
    private var summaryRevision = 0
    public private(set) var cleanupFailed = false

    @ObservationIgnored private let catalog: AudioCatalog
    @ObservationIgnored private let store: AudioDownloadFileStore
    @ObservationIgnored private let client: AudioDownloadClient
    @ObservationIgnored private var states: [RecordingID: AudioDownloadState] = [:]
    @ObservationIgnored private var tasks: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var pending: [(recording: RecordingID, url: URL, id: UUID)] = []
    private static let maximumActiveTransfers = 2
    @ObservationIgnored private var operationIDs: [RecordingID: UUID] = [:]
    @ObservationIgnored private var downloadedRecordings: Set<RecordingID> = []
    @ObservationIgnored private var catalogOrder: [RecordingID: Int] = [:]

    public init(catalog: AudioCatalog,
                store: AudioDownloadFileStore,
                client: AudioDownloadClient? = nil) {
        self.catalog = catalog
        self.store = store
        self.client = client ?? URLSessionAudioDownloadClient(transferDirectory: store.transferDirectory)
        downloadedRecordings = store.storedRecordings()
        var order = 0
        var seenCollections = Set<RecordingCollectionID>()
        for reciter in catalog.reciters where seenCollections.insert(reciter.collection.id).inserted {
            for surahNumber in Surah.numberRange {
                let recording = RecordingID(collection: reciter.collection.id,
                                            surahNumber: surahNumber)
                catalogOrder[recording] = order
                order += 1
            }
        }
    }

    public var storageSummary: DownloadStorageSummary {
        _ = summaryRevision
        return store.storageSummary()
    }

    /// Durable downloads plus in-flight and failed operations, in catalog/surah order.
    ///
    /// The file store remains the source of truth, so this remains useful after relaunch and
    /// while offline without introducing a second download database.
    public var downloadItems: [AudioDownloadItem] {
        _ = stateRevision
        _ = summaryRevision
        let recordings = downloadedRecordings.union(states.keys).sorted(by: inventoryOrder)
        var items: [AudioDownloadItem] = []
        for recording in recordings {
            let state = resolvedState(for: recording)
            guard state != .notDownloaded else { continue }
            items.append(AudioDownloadItem(recording: recording,
                                           state: state,
                                           byteCount: store.byteCount(for: recording)))
        }
        return items
    }

    public func state(for recording: RecordingID) -> AudioDownloadState {
        _ = stateRevision
        return resolvedState(for: recording)
    }

    public func canDownload(_ recording: RecordingID) -> Bool {
        guard let source = try? catalog.source(for: recording) else { return false }
        return !source.isTestFixture && !source.url.isFileURL
    }

    public func download(_ recording: RecordingID) {
        guard operationIDs[recording] == nil else { return }
        guard let source = try? catalog.source(for: recording),
              !source.isTestFixture,
              !source.url.isFileURL else {
            updateState(.failed(.unavailable), for: recording)
            return
        }

        updateState(.downloading(progress: nil), for: recording)
        let operationID = UUID()
        operationIDs[recording] = operationID
        pending.append((recording, source.url, operationID))
        startPendingDownloads()
    }

    private func startPendingDownloads() {
        while tasks.count < Self.maximumActiveTransfers, !pending.isEmpty {
            let request = pending.removeFirst()
            tasks[request.id] = Task { [weak self] in
                await self?.runDownload(request.recording, url: request.url, operationID: request.id)
            }
        }
    }

    private func runDownload(_ recording: RecordingID, url: URL, operationID: UUID) async {
        defer {
            tasks[operationID] = nil
            if operationIDs[recording] == operationID { operationIDs[recording] = nil }
            startPendingDownloads()
        }
        do {
            try Task.checkCancellation()
            let temporaryURL = try await client.download(from: url) { [weak self] progress in
                Task { @MainActor [weak self] in
                    guard let self, self.operationIDs[recording] == operationID else { return }
                    self.updateState(.downloading(progress: progress), for: recording)
                }
            }
            defer { try? FileManager.default.removeItem(at: temporaryURL) }
            try Task.checkCancellation()
            try store.installDownloadedFile(at: temporaryURL, for: recording)
            downloadedRecordings.insert(recording)
            updateState(.downloaded, for: recording)
            summaryRevision &+= 1
        } catch {
            // A cancellation may have been followed by a new request for this recording.
            guard operationIDs[recording] == operationID else { return }
            let failure: AudioDownloadFailure
            switch error {
            case is CancellationError:
                updateState(.notDownloaded, for: recording)
                return
            case AudioDownloadFileStoreError.invalidDownloadedFile:
                failure = .network
            case is AudioDownloadFileStoreError, AudioDownloadClientError.writeFailed,
                 AudioDownloadClientError.tooLarge:
                failure = .storage
            default:
                failure = .network
            }
            updateState(.failed(failure), for: recording)
        }
    }

    public func cancel(_ recording: RecordingID) {
        if let operationID = operationIDs.removeValue(forKey: recording) {
            pending.removeAll { $0.id == operationID }
            tasks[operationID]?.cancel()
        }
        updateState(.notDownloaded, for: recording)
    }

    public func retry(_ recording: RecordingID) {
        if case .failed(.storage) = resolvedState(for: recording),
           store.localURL(for: recording) != nil {
            remove(recording)
        } else {
            download(recording)
        }
    }

    public func remove(_ recording: RecordingID) {
        cancel(recording)
        do {
            try store.remove(recording)
            downloadedRecordings.remove(recording)
            updateState(.notDownloaded, for: recording)
            summaryRevision &+= 1
        } catch {
            updateState(.failed(.storage), for: recording)
        }
    }

    public func removeAll() {
        cleanupFailed = false
        operationIDs.removeAll()
        pending.removeAll()
        for task in tasks.values { task.cancel() }
        states.removeAll()
        stateRevision &+= 1
        do {
            try store.removeAll()
            downloadedRecordings.removeAll()
            summaryRevision &+= 1
        } catch {
            // The computed summary continues to report files that could not be removed.
            downloadedRecordings = store.storedRecordings()
            cleanupFailed = true
            summaryRevision &+= 1
        }
    }

    private func updateState(_ state: AudioDownloadState, for recording: RecordingID) {
        if state == .notDownloaded {
            states[recording] = nil
        } else {
            states[recording] = state
        }
        stateRevision &+= 1
    }

    private func resolvedState(for recording: RecordingID) -> AudioDownloadState {
        if let state = states[recording] {
            if state == .downloaded, store.localURL(for: recording) == nil {
                return .notDownloaded
            }
            return state
        }
        return downloadedRecordings.contains(recording) && store.localURL(for: recording) != nil
            ? .downloaded
            : .notDownloaded
    }

    private func inventoryOrder(_ lhs: RecordingID, _ rhs: RecordingID) -> Bool {
        switch (catalogOrder[lhs], catalogOrder[rhs]) {
        case let (left?, right?): return left < right
        case (_?, nil): return true
        case (nil, _?): return false
        case (nil, nil):
            if lhs.collection.provider != rhs.collection.provider {
                return lhs.collection.provider < rhs.collection.provider
            }
            if lhs.collection.collection != rhs.collection.collection {
                return lhs.collection.collection < rhs.collection.collection
            }
            return lhs.surahNumber < rhs.surahNumber
        }
    }
}
