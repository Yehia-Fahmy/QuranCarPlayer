import CryptoKit
import Foundation
import StoreKit
import UIKit

/// Provides the 1954 Radio Magazine portrait only while StoreKit confirms a permitted storefront.
/// The original file is retrieved on demand. No image or prior storefront grant ships in the app.
@MainActor
final class RegionalMinshawiPortraitStore {
    nonisolated static let sourceURL = URL(string: "https://upload.wikimedia.org/wikipedia/commons/d/da/Al-Minshawi_1954.jpg")!
    private static let sourceDigest = "3faa9b1ca3ab146b7390afcb63dbf60627f78289cab06c58215ef5ab075ae296"
    nonisolated private static let sourceSize = 303_554

    private(set) var image: UIImage?
    /// Called both when a usable image arrives and when previously rendered artwork must be cleared.
    var onChange: (() -> Void)?

    private let directory: URL
    private let expectedDigest: String
    private let fetch: @Sendable () async throws -> Data
    private var storefrontIsAllowed = false
    private var nextAttempt = Date.distantPast
    private var revision: UInt = 0
    private var load: Task<Void, Never>?
    private var updates: Task<Void, Never>?
    private var lookup: Task<Void, Never>?
    private var lifecycle: NSObjectProtocol?
    private var file: URL { directory.appendingPathComponent("minshawi-1954.jpg") }

    convenience init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.init(directory: caches.appendingPathComponent("RegionalReciterPortraits", isDirectory: true),
                  expectedDigest: Self.sourceDigest, fetch: { try await Self.fetchOriginal() })
    }

    init(directory: URL, expectedDigest: String, fetch: @escaping @Sendable () async throws -> Data) {
        self.directory = directory
        self.expectedDigest = expectedDigest
        self.fetch = fetch
    }

    /// Call only when Minshawi's artwork is requested. Repeated requests share one lookup and transfer.
    func request() {
        if updates != nil {
            if storefrontIsAllowed { _ = loadIfNeeded() }
            return
        }
        updates = Task { [weak self] in
            for await storefront in Storefront.updates {
                guard let self, !Task.isCancelled else { return }
                self.lookup?.cancel()
                self.confirmStorefront(storefront.countryCode)
            }
        }
        lifecycle = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification,
                                                           object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshStorefront() }
        }
        refreshStorefront()
    }

    private func refreshStorefront() {
        lookup?.cancel()
        // Never show a disk or memory copy on the basis of the previous foreground session alone.
        confirmStorefront(nil)
        lookup = Task { [weak self] in
            let country = await Storefront.current?.countryCode
            guard !Task.isCancelled else { return }
            self?.confirmStorefront(country)
        }
    }

    @discardableResult
    func confirmStorefront(_ country: String?) -> Task<Void, Never>? {
        let allowed = country == "CAN" || country == "USA"
        guard allowed else {
            storefrontIsAllowed = false
            revision &+= 1
            load?.cancel()
            load = nil
            // Keep the private cache during temporarily unknown eligibility so an allowed
            // storefront can reuse it offline. A confirmed move elsewhere removes the copy.
            if country != nil { try? FileManager.default.removeItem(at: file) }
            if image != nil {
                image = nil
                onChange?()
            }
            return nil
        }
        storefrontIsAllowed = true
        return loadIfNeeded()
    }

    private func loadIfNeeded() -> Task<Void, Never>? {
        guard image == nil, load == nil else { return load }
        if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           size <= Self.sourceSize, let cached = try? Data(contentsOf: file), let portrait = verifiedImage(cached) {
            image = portrait
            onChange?()
            return nil
        }
        guard nextAttempt <= Date() else { return nil }
        let generation = revision
        load = Task { [weak self, fetch] in
            // Recover while the same artwork stays onscreen. Further attempts are rate-limited.
            for delay in [0, 2, 10] {
                if delay > 0 {
                    do { try await Task.sleep(for: .seconds(delay)) }
                    catch { return }
                }
                guard !Task.isCancelled else { return }
                do {
                    let bytes = try await fetch()
                    guard let self, !Task.isCancelled, self.revision == generation else { return }
                    if let portrait = self.verifiedImage(bytes) {
                        self.cache(bytes)
                        self.image = portrait
                        self.load = nil
                        self.onChange?()
                        return
                    }
                    break
                } catch {
                    if Task.isCancelled { return }
                }
            }
            guard let self, self.revision == generation else { return }
            self.nextAttempt = Date().addingTimeInterval(300)
            self.load = nil
        }
        return load
    }

    private func verifiedImage(_ data: Data) -> UIImage? {
        guard data.count <= Self.sourceSize else { return nil }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return digest == expectedDigest ? UIImage(data: data) : nil
    }

    private func cache(_ data: Data) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var cacheDirectory = directory
            var attributes = URLResourceValues()
            attributes.isExcludedFromBackup = true
            try cacheDirectory.setResourceValues(attributes)
            try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            // An unavailable or full cache directory still permits in-memory display.
        }
    }

    nonisolated private static func fetchOriginal() async throws -> Data {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForResource = 25
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let (stream, response) = try await session.bytes(from: sourceURL)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              http.url == sourceURL,
              http.expectedContentLength == -1 || http.expectedContentLength == Int64(sourceSize)
        else { throw URLError(.badServerResponse) }
        var data = Data()
        data.reserveCapacity(sourceSize)
        for try await byte in stream {
            guard data.count < sourceSize else { throw URLError(.dataLengthExceedsMaximum) }
            data.append(byte)
        }
        guard data.count == sourceSize else { throw URLError(.cannotDecodeContentData) }
        return data
    }

    deinit {
        lookup?.cancel()
        load?.cancel()
        updates?.cancel()
        if let lifecycle { NotificationCenter.default.removeObserver(lifecycle) }
    }
}
