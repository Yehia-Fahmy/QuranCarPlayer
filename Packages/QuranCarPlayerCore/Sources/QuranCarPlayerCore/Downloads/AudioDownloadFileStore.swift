import Foundation

/// Synchronously resolves verified local recordings for playback.
///
/// Playback only needs this small boundary; download networking and UI state remain separate.
public protocol DownloadedAudioResolving: Sendable {
    func localURL(for recording: RecordingID) -> URL?
    func invalidateDownloadedAudio(for recording: RecordingID)
}

public extension DownloadedAudioResolving {
    func invalidateDownloadedAudio(for recording: RecordingID) {}
}

public struct DownloadStorageSummary: Equatable, Sendable {
    public let fileCount: Int
    public let byteCount: Int64

    public init(fileCount: Int, byteCount: Int64) {
        self.fileCount = fileCount
        self.byteCount = byteCount
    }

    public static let empty = DownloadStorageSummary(fileCount: 0, byteCount: 0)
}

public enum AudioDownloadFileStoreError: Error, Equatable {
    case unableToCreateDirectory
    case invalidDownloadedFile
    case unableToInstallFile
    case unableToRemoveFile
}

/// Persistent, app-owned audio storage.
///
/// Recording IDs are encoded instead of being used as path components, preventing provider
/// metadata from escaping the download directory. Installs use a same-directory staging file
/// followed by an atomic rename. Incomplete staging files are removed on initialization.
public final class AudioDownloadFileStore: DownloadedAudioResolving, @unchecked Sendable {
    private let rootDirectory: URL
    private let fileManager: FileManager
    private let lock = NSLock()

    public init(rootDirectory: URL, fileManager: FileManager = .default) throws {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
        do {
            try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var directory = rootDirectory
            try? directory.setResourceValues(values)
            try removeIncompleteFiles()
        } catch {
            throw AudioDownloadFileStoreError.unableToCreateDirectory
        }
    }

    public static func applicationSupport(fileManager: FileManager = .default) throws -> AudioDownloadFileStore {
        guard let applicationSupport = fileManager.urls(for: .applicationSupportDirectory,
                                                        in: .userDomainMask).first else {
            throw AudioDownloadFileStoreError.unableToCreateDirectory
        }
        return try AudioDownloadFileStore(
            rootDirectory: applicationSupport
                .appendingPathComponent("QuranCarPlayer", isDirectory: true)
                .appendingPathComponent("Audio Downloads", isDirectory: true),
            fileManager: fileManager
        )
    }

    public func localURL(for recording: RecordingID) -> URL? {
        lock.qcpWithLock {
            let url = destinationURL(for: recording)
            guard isValidFile(at: url) else { return nil }
            return url
        }
    }

    public func invalidateDownloadedAudio(for recording: RecordingID) {
        try? remove(recording)
    }

    /// Moves a completed temporary download into persistent storage.
    public func installDownloadedFile(at temporaryURL: URL, for recording: RecordingID) throws {
        try lock.qcpWithLock {
            guard isValidFile(at: temporaryURL) else {
                try? fileManager.removeItem(at: temporaryURL)
                throw AudioDownloadFileStoreError.invalidDownloadedFile
            }

            let destination = destinationURL(for: recording)
            let directory = destination.deletingLastPathComponent()
            let staging = directory.appendingPathComponent(".\(destination.lastPathComponent).download")
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                if fileManager.fileExists(atPath: staging.path) {
                    try fileManager.removeItem(at: staging)
                }
                try fileManager.moveItem(at: temporaryURL, to: staging)
                if fileManager.fileExists(atPath: destination.path) {
                    _ = try fileManager.replaceItemAt(destination, withItemAt: staging)
                } else {
                    try fileManager.moveItem(at: staging, to: destination)
                }
                var values = URLResourceValues()
                values.isExcludedFromBackup = true
                var installed = destination
                try? installed.setResourceValues(values)
            } catch {
                try? fileManager.removeItem(at: staging)
                try? fileManager.removeItem(at: temporaryURL)
                throw AudioDownloadFileStoreError.unableToInstallFile
            }
        }
    }

    public func remove(_ recording: RecordingID) throws {
        try lock.qcpWithLock {
            let destination = destinationURL(for: recording)
            guard fileManager.fileExists(atPath: destination.path) else { return }
            do {
                try fileManager.removeItem(at: destination)
                let directory = destination.deletingLastPathComponent()
                if (try? fileManager.contentsOfDirectory(atPath: directory.path).isEmpty) == true {
                    try? fileManager.removeItem(at: directory)
                }
            } catch {
                throw AudioDownloadFileStoreError.unableToRemoveFile
            }
        }
    }

    public func removeAll() throws {
        try lock.qcpWithLock {
            do {
                if fileManager.fileExists(atPath: rootDirectory.path) {
                    try fileManager.removeItem(at: rootDirectory)
                }
                try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
            } catch {
                throw AudioDownloadFileStoreError.unableToRemoveFile
            }
        }
    }

    public func storageSummary() -> DownloadStorageSummary {
        lock.qcpWithLock {
            guard let enumerator = fileManager.enumerator(
                at: rootDirectory,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else {
                return .empty
            }
            var count = 0
            var bytes: Int64 = 0
            for case let url as URL in enumerator {
                guard url.pathExtension == "audio",
                      let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                      values.isRegularFile == true else { continue }
                count += 1
                bytes += Int64(values.fileSize ?? 0)
            }
            return DownloadStorageSummary(fileCount: count, byteCount: bytes)
        }
    }

    private func removeIncompleteFiles() throws {
        guard let enumerator = fileManager.enumerator(at: rootDirectory,
                                                      includingPropertiesForKeys: nil) else { return }
        for case let url as URL in enumerator where url.lastPathComponent.hasSuffix(".download") {
            try? fileManager.removeItem(at: url)
        }
    }

    private func destinationURL(for recording: RecordingID) -> URL {
        let collectionKey = encoded("\(recording.collection.provider):\(recording.collection.collection)")
        return rootDirectory
            .appendingPathComponent(collectionKey, isDirectory: true)
            .appendingPathComponent(String(format: "%03d.audio", recording.surahNumber))
    }

    private func encoded(_ value: String) -> String {
        Data(value.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
    }

    private func isValidFile(at url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]) else {
            return false
        }
        return values.isRegularFile == true && (values.fileSize ?? 0) > 0
    }
}

extension NSLock {
    func qcpWithLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
