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

/// Coordinates user-initiated recording downloads and exposes per-recording UI state.
@Observable
@MainActor
public final class AudioDownloadManager {
    private var stateRevision = 0
    private var summaryRevision = 0

    @ObservationIgnored private let catalog: AudioCatalog
    @ObservationIgnored private let store: AudioDownloadFileStore
    @ObservationIgnored private let client: AudioDownloadClient
    @ObservationIgnored private var states: [RecordingID: AudioDownloadState] = [:]
    @ObservationIgnored private var tasks: [RecordingID: Task<Void, Never>] = [:]
    @ObservationIgnored private var operationIDs: [RecordingID: UUID] = [:]

    public init(catalog: AudioCatalog,
                store: AudioDownloadFileStore,
                client: AudioDownloadClient = URLSessionAudioDownloadClient()) {
        self.catalog = catalog
        self.store = store
        self.client = client
    }

    public var storageSummary: DownloadStorageSummary {
        _ = summaryRevision
        return store.storageSummary()
    }

    public func state(for recording: RecordingID) -> AudioDownloadState {
        _ = stateRevision
        if let state = states[recording] {
            if state == .downloaded, store.localURL(for: recording) == nil {
                return .notDownloaded
            }
            return state
        }
        return store.localURL(for: recording) == nil ? .notDownloaded : .downloaded
    }

    public func canDownload(_ recording: RecordingID) -> Bool {
        guard let source = try? catalog.source(for: recording) else { return false }
        return !source.isTestFixture && !source.url.isFileURL
    }

    public func download(_ recording: RecordingID) {
        guard tasks[recording] == nil else { return }
        guard let source = try? catalog.source(for: recording),
              !source.isTestFixture,
              !source.url.isFileURL else {
            updateState(.failed(.unavailable), for: recording)
            return
        }

        updateState(.downloading(progress: nil), for: recording)
        let operationID = UUID()
        operationIDs[recording] = operationID
        tasks[recording] = Task { [weak self, client, store] in
            do {
                let temporaryURL = try await client.download(from: source.url) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        guard let self, self.operationIDs[recording] == operationID else { return }
                        self.updateState(.downloading(progress: progress), for: recording)
                    }
                }
                defer { try? FileManager.default.removeItem(at: temporaryURL) }
                try Task.checkCancellation()
                try store.installDownloadedFile(at: temporaryURL, for: recording)
                guard let self, self.operationIDs[recording] == operationID else { return }
                self.tasks[recording] = nil
                self.operationIDs[recording] = nil
                self.updateState(.downloaded, for: recording)
                self.summaryRevision &+= 1
            } catch is CancellationError {
                guard let self, self.operationIDs[recording] == operationID else { return }
                self.tasks[recording] = nil
                self.operationIDs[recording] = nil
                self.updateState(.notDownloaded, for: recording)
            } catch let error as AudioDownloadFileStoreError {
                guard let self, self.operationIDs[recording] == operationID else { return }
                self.tasks[recording] = nil
                self.operationIDs[recording] = nil
                self.updateState(error == .invalidDownloadedFile ? .failed(.network) : .failed(.storage),
                                 for: recording)
            } catch {
                guard let self, self.operationIDs[recording] == operationID else { return }
                self.tasks[recording] = nil
                self.operationIDs[recording] = nil
                self.updateState(.failed(.network), for: recording)
            }
        }
    }

    public func cancel(_ recording: RecordingID) {
        operationIDs[recording] = nil
        tasks.removeValue(forKey: recording)?.cancel()
        updateState(.notDownloaded, for: recording)
    }

    public func remove(_ recording: RecordingID) {
        cancel(recording)
        do {
            try store.remove(recording)
            updateState(.notDownloaded, for: recording)
            summaryRevision &+= 1
        } catch {
            updateState(.failed(.storage), for: recording)
        }
    }

    public func removeAll() {
        operationIDs.removeAll()
        for task in tasks.values { task.cancel() }
        tasks.removeAll()
        do {
            try store.removeAll()
            states.removeAll()
            stateRevision &+= 1
            summaryRevision &+= 1
        } catch {
            // The computed summary continues to report files that could not be removed.
            summaryRevision &+= 1
        }
    }

    private func updateState(_ state: AudioDownloadState, for recording: RecordingID) {
        states[recording] = state
        stateRevision &+= 1
    }
}
