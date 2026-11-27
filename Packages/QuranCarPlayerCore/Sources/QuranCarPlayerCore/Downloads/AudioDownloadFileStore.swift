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
    // If relocation fails (for example while storage is full), the original path stays usable.
    private var unmigratedDirectories: [RecordingCollectionID: [URL]] = [:]
    var transferDirectory: URL { rootDirectory.appendingPathComponent(".transfers", isDirectory: true) }
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
            if fileManager.fileExists(atPath: transferDirectory.path) {
                try fileManager.removeItem(at: transferDirectory)
            }
            migrateLegacyCollectionDirectories()
            removeIncompleteFiles()
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
        let store = try AudioDownloadFileStore(
            rootDirectory: applicationSupport
                .appendingPathComponent("QuranCarPlayer", isDirectory: true)
                .appendingPathComponent("Audio Downloads", isDirectory: true),
            fileManager: fileManager
        )
        // Earlier versions staged foreground transfers directly in the app's temporary directory.
        // Only their exact filename pattern is eligible for cleanup.
        if let files = try? fileManager.contentsOfDirectory(at: fileManager.temporaryDirectory,
                                                            includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "download" {
                let stem = file.deletingPathExtension().lastPathComponent
                if stem.hasPrefix("qcp-"), UUID(uuidString: String(stem.dropFirst(4))) != nil {
                    try? fileManager.removeItem(at: file)
                }
            }
        }
        return store
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
            let destinations = possibleURLs(for: recording).flatMap { url in
                [url, url.deletingPathExtension().appendingPathExtension("audio")]
            }.filter { fileManager.fileExists(atPath: $0.path) }
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
                unmigratedDirectories.removeAll()
                try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
                var values = URLResourceValues()
                values.isExcludedFromBackup = true
                var directory = rootDirectory
                try directory.setResourceValues(values)
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
                for file in files where isStoredAudio(file) && isValidFile(at: file) {
                    guard let number = Int(file.deletingPathExtension().lastPathComponent),
                          Surah.numberRange.contains(number) else { continue }
                    recordings.insert(RecordingID(collection: collection, surahNumber: number))
                }
            }
            return recordings
        }
    }

    private func removeIncompleteFiles() {
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
        where isStoredAudio(url) && !isValidFile(at: url) {
            try? fileManager.removeItem(at: url)
        }
    }

    private func destinationURL(for recording: RecordingID) -> URL {
        let collectionKey = encodedCollection(recording.collection)
        return rootDirectory
            .appendingPathComponent(collectionKey, isDirectory: true)
            .appendingPathComponent(String(format: "%03d.mp3", recording.surahNumber))
    }

    private func possibleURLs(for recording: RecordingID) -> [URL] {
        let current = destinationURL(for: recording)
        let otherDirectories = unmigratedDirectories[recording.collection] ?? []
        return [current] + otherDirectories.map { $0.appendingPathComponent(current.lastPathComponent) }
    }

    private func availableURL(for recording: RecordingID) -> URL? {
        for url in possibleURLs(for: recording) {
            if isValidFile(at: url) { return url }
            // Retry a migration interrupted by a full disk or transient file protection.
            let legacy = url.deletingPathExtension().appendingPathExtension("audio")
            if isValidFile(at: legacy), (try? fileManager.moveItem(at: legacy, to: url)) != nil { return url }
        }
        return nil
    }

    private func encodedCollection(_ collection: RecordingCollectionID) -> String {
        let components = CollectionPathComponents(provider: collection.provider,
                                                  collection: collection.collection)
        // Encoding this fixed pair of strings cannot fail.
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try! encoder.encode(components)
        return data.base64EncodedString()
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

    /// Merge both historical JSON key orders and the original colon-delimited directory format.
    private func migrateLegacyCollectionDirectories() {
        guard let directories = try? fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        for oldDirectory in directories {
            guard let collection = decodedCollection(oldDirectory.lastPathComponent) else { continue }
            let currentName = encodedCollection(collection)
            let isCanonicalDirectory = oldDirectory.lastPathComponent == currentName
            let currentDirectory = rootDirectory.appendingPathComponent(currentName, isDirectory: true)
            do {
                try fileManager.createDirectory(at: currentDirectory, withIntermediateDirectories: true)
                let files = try fileManager.contentsOfDirectory(at: oldDirectory,
                                                                includingPropertiesForKeys: nil)
                for file in files where isStoredAudio(file) {
                    if isCanonicalDirectory && file.pathExtension == "mp3" { continue }
                    let destination = currentDirectory
                        .appendingPathComponent(file.deletingPathExtension().lastPathComponent)
                        .appendingPathExtension("mp3")
                    if !fileManager.fileExists(atPath: destination.path) {
                        try fileManager.moveItem(at: file, to: destination)
                    } else if isValidFile(at: destination) {
                        try fileManager.removeItem(at: file)
                    } else {
                        try fileManager.removeItem(at: destination)
                        try fileManager.moveItem(at: file, to: destination)
                    }
                }
                if !isCanonicalDirectory, try fileManager.contentsOfDirectory(atPath: oldDirectory.path).isEmpty {
                    try fileManager.removeItem(at: oldDirectory)
                }
            } catch {
                if !isCanonicalDirectory { unmigratedDirectories[collection, default: []].append(oldDirectory) }
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
            guard isStoredAudio(url),
                  let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true,
                  let fileSize = values.fileSize,
                  fileSize > 0 else { continue }
            count += 1
            bytes += Int64(fileSize)
        }
        return DownloadStorageSummary(fileCount: count, byteCount: bytes)
    }

    private func isStoredAudio(_ url: URL) -> Bool {
        url.pathExtension == "mp3" || url.pathExtension == "audio"
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
