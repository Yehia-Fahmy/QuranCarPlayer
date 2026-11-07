import Foundation

/// Persists the versioned session checkpoint.
public protocol SessionStore: AnyObject {
    func load() throws -> SessionCheckpoint?
    func save(_ checkpoint: SessionCheckpoint) throws
    func clear() throws
}

/// Persists small user preferences.
public protocol SettingsStore: AnyObject {
    func load() -> AppSettings?
    func save(_ settings: AppSettings)
}

// MARK: - In-memory (tests, previews)

public final class InMemorySessionStore: SessionStore {
    public private(set) var checkpoint: SessionCheckpoint?
    public private(set) var saveCount = 0
    public var failNextSave = false

    public init(checkpoint: SessionCheckpoint? = nil) { self.checkpoint = checkpoint }

    public func load() throws -> SessionCheckpoint? { checkpoint }

    public func save(_ checkpoint: SessionCheckpoint) throws {
        if failNextSave {
            failNextSave = false
            throw CocoaError(.fileWriteUnknown)
        }
        self.checkpoint = checkpoint
        saveCount += 1
    }

    public func clear() throws { checkpoint = nil }
}

public final class InMemorySettingsStore: SettingsStore {
    public private(set) var settings: AppSettings?
    public init(settings: AppSettings? = nil) { self.settings = settings }
    public func load() -> AppSettings? { settings }
    public func save(_ settings: AppSettings) { self.settings = settings }
}

// MARK: - File-backed session checkpoint (atomic JSON writes)

public final class FileSessionStore: SessionStore {
    public let fileURL: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    public init(fileURL: URL) { self.fileURL = fileURL }

    /// Default location inside the app's Application Support directory.
    public static func applicationSupport(fileManager: FileManager = .default) throws -> FileSessionStore {
        let base = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                       appropriateFor: nil, create: true)
        let dir = base.appendingPathComponent("QuranCarPlayer", isDirectory: true)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return FileSessionStore(fileURL: dir.appendingPathComponent("session.json"))
    }

    public func load() throws -> SessionCheckpoint? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        let checkpoint = try decoder.decode(SessionCheckpoint.self, from: data)
        // Unknown future versions are discarded rather than misinterpreted.
        guard checkpoint.version == SessionCheckpoint.currentVersion else { return nil }
        return checkpoint
    }

    public func save(_ checkpoint: SessionCheckpoint) throws {
        let data = try encoder.encode(checkpoint)
        try data.write(to: fileURL, options: [.atomic])
    }

    public func clear() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}

// MARK: - UserDefaults-backed settings

public final class UserDefaultsSettingsStore: SettingsStore {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "QuranCarPlayer.settings.v1") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> AppSettings? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(AppSettings.self, from: data)
    }

    public func save(_ settings: AppSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: key)
        }
    }
}
