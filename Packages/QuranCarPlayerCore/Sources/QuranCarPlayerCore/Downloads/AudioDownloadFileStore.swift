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
    private var cachedSummary: DownloadStorageSummary = .empty

    public init(rootDirectory: URL, fileManager: FileManager = .default) throws {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
        do {
            try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var directory = rootDirectory
            try? directory.setResourceValues(values)
            migrateLegacyCollectionDirectories()
            try removeIncompleteFiles()
            removeInvalidAudioFiles()
            cachedSummary = calculateStorageSummary()
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
            availableURL(for: recording)
        }
    }

    public func byteCount(for recording: RecordingID) -> Int64? {
        lock.qcpWithLock {
            guard let url = availableURL(for: recording),
                  let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = values.fileSize else { return nil }
            return Int64(fileSize)
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
                cachedSummary = calculateStorageSummary()
            } catch {
                try? fileManager.removeItem(at: staging)
                try? fileManager.removeItem(at: temporaryURL)
                throw AudioDownloadFileStoreError.unableToInstallFile
            }
        }
    }

    public func remove(_ recording: RecordingID) throws {
        try lock.qcpWithLock {
            var destinations = [destinationURL(for: recording)]
            if let legacyCollectionKey = legacyEncodedCollection(recording.collection) {
                destinations.append(
                    rootDirectory
                        .appendingPathComponent(legacyCollectionKey, isDirectory: true)
                        .appendingPathComponent(String(format: "%03d.audio", recording.surahNumber))
                )
            }
            destinations = destinations.filter { fileManager.fileExists(atPath: $0.path) }
            guard !destinations.isEmpty else { return }
            do {
                for destination in destinations {
                    try fileManager.removeItem(at: destination)
                    let directory = destination.deletingLastPathComponent()
                    if (try? fileManager.contentsOfDirectory(atPath: directory.path).isEmpty) == true {
                        try? fileManager.removeItem(at: directory)
                    }
                }
                cachedSummary = calculateStorageSummary()
            } catch {
                cachedSummary = calculateStorageSummary()
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
                cachedSummary = .empty
                try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
            } catch {
                throw AudioDownloadFileStoreError.unableToRemoveFile
            }
        }
    }

    public func storageSummary() -> DownloadStorageSummary {
        lock.qcpWithLock { cachedSummary }
    }

    /// Reconstructs the durable inventory from encoded paths without requiring network metadata.
    public func storedRecordings() -> Set<RecordingID> {
        lock.qcpWithLock {
            guard let collectionDirectories = try? fileManager.contentsOfDirectory(
                at: rootDirectory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { return [] }
            var recordings = Set<RecordingID>()
            for directory in collectionDirectories {
                guard let collection = decodedCollection(directory.lastPathComponent),
                      let files = try? fileManager.contentsOfDirectory(
                        at: directory,
                        includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                        options: [.skipsHiddenFiles]
                      ) else { continue }
                for file in files where file.pathExtension == "audio" && isValidFile(at: file) {
                    guard let number = Int(file.deletingPathExtension().lastPathComponent),
                          Surah.numberRange.contains(number) else { continue }
                    recordings.insert(RecordingID(collection: collection, surahNumber: number))
                }
            }
            return recordings
        }
    }

    private func removeIncompleteFiles() throws {
        guard let enumerator = fileManager.enumerator(at: rootDirectory,
                                                      includingPropertiesForKeys: nil) else { return }
        for case let url as URL in enumerator where url.lastPathComponent.hasSuffix(".download") {
            try? fileManager.removeItem(at: url)
        }
    }

    private func removeInvalidAudioFiles() {
        guard let enumerator = fileManager.enumerator(at: rootDirectory,
                                                      includingPropertiesForKeys: nil) else { return }
        for case let url as URL in enumerator
        where url.pathExtension == "audio" && !isValidFile(at: url) {
            try? fileManager.removeItem(at: url)
        }
    }

    private func destinationURL(for recording: RecordingID) -> URL {
        let collectionKey = encodedCollection(recording.collection)
        return rootDirectory
            .appendingPathComponent(collectionKey, isDirectory: true)
            .appendingPathComponent(String(format: "%03d.audio", recording.surahNumber))
    }

    private func availableURL(for recording: RecordingID) -> URL? {
        let current = destinationURL(for: recording)
        if isValidFile(at: current) { return current }
        guard let legacyCollectionKey = legacyEncodedCollection(recording.collection) else {
            return nil
        }
        let legacy = rootDirectory
            .appendingPathComponent(legacyCollectionKey, isDirectory: true)
            .appendingPathComponent(String(format: "%03d.audio", recording.surahNumber))
        return isValidFile(at: legacy) ? legacy : nil
    }

    private func encodedCollection(_ collection: RecordingCollectionID) -> String {
        let components = CollectionPathComponents(provider: collection.provider,
                                                  collection: collection.collection)
        // Encoding this fixed pair of strings cannot fail.
        let data = try! JSONEncoder().encode(components)
        return data.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
    }

    private func legacyEncodedCollection(_ collection: RecordingCollectionID) -> String? {
        guard !collection.provider.contains(":"), !collection.collection.contains(":") else {
            return nil
        }
        return Data("\(collection.provider):\(collection.collection)".utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
    }

    private func decodedCollection(_ value: String) -> RecordingCollectionID? {
        var base64 = value
            .replacingOccurrences(of: "_", with: "/")
            .replacingOccurrences(of: "-", with: "+")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64) else { return nil }
        if let components = try? JSONDecoder().decode(CollectionPathComponents.self, from: data),
           !components.provider.isEmpty,
           !components.collection.isEmpty {
            return RecordingCollectionID(provider: components.provider,
                                         collection: components.collection)
        }
        guard let decoded = String(data: data, encoding: .utf8),
              let separator = decoded.firstIndex(of: ":") else { return nil }
        let provider = String(decoded[..<separator])
        let collection = String(decoded[decoded.index(after: separator)...])
        guard !provider.isEmpty, !collection.isEmpty else { return nil }
        return RecordingCollectionID(provider: provider, collection: collection)
    }

    /// PR #2 used a single colon-delimited component. Current known IDs contain no colon, so
    /// those directories can be losslessly migrated to the structured encoding.
    private func migrateLegacyCollectionDirectories() {
        guard let directories = try? fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        for oldDirectory in directories {
            guard let collection = decodedCollection(oldDirectory.lastPathComponent) else { continue }
            let currentName = encodedCollection(collection)
            guard oldDirectory.lastPathComponent != currentName else { continue }
            let currentDirectory = rootDirectory.appendingPathComponent(currentName, isDirectory: true)
            do {
                try fileManager.createDirectory(at: currentDirectory, withIntermediateDirectories: true)
                let files = try fileManager.contentsOfDirectory(at: oldDirectory,
                                                                includingPropertiesForKeys: nil)
                for file in files {
                    let destination = currentDirectory.appendingPathComponent(file.lastPathComponent)
                    if !fileManager.fileExists(atPath: destination.path) {
                        try fileManager.moveItem(at: file, to: destination)
                    } else if isValidFile(at: destination) {
                        try fileManager.removeItem(at: file)
                    } else {
                        try fileManager.removeItem(at: destination)
                        try fileManager.moveItem(at: file, to: destination)
                    }
                }
                try? fileManager.removeItem(at: oldDirectory)
            } catch {
                // Leave the legacy directory intact; storedRecordings can still enumerate it.
            }
        }
    }

    private func calculateStorageSummary() -> DownloadStorageSummary {
        guard let enumerator = fileManager.enumerator(
            at: rootDirectory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return .empty }
        var count = 0
        var bytes: Int64 = 0
        for case let url as URL in enumerator {
            guard url.pathExtension == "audio",
                  let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true,
                  let fileSize = values.fileSize,
                  fileSize > 0 else { continue }
            count += 1
            bytes += Int64(fileSize)
        }
        return DownloadStorageSummary(fileCount: count, byteCount: bytes)
    }

    private func isValidFile(at url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]) else {
            return false
        }
        return values.isRegularFile == true && (values.fileSize ?? 0) > 0
    }
}

private struct CollectionPathComponents: Codable {
    let provider: String
    let collection: String
}

extension NSLock {
    func qcpWithLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
