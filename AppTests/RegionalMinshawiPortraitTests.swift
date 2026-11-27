import CryptoKit
import Foundation
import QuranCarPlayerCore
import Testing
import UIKit
@testable import QuranCarPlayer

@MainActor
struct RegionalMinshawiPortraitTests {
    @Test("Only the two verified storefronts can fetch or see the photo, including after relaunch")
    func storefrontsAndCache() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let bytes = portraitBytes()
        let digest = sha256(bytes)
        let store = RegionalMinshawiPortraitStore(directory: directory, expectedDigest: digest) { bytes }
        var changes = 0
        store.onChange = { changes += 1 }
        #expect(store.confirmStorefront(nil) == nil)
        #expect(store.confirmStorefront("CA") == nil)
        #expect(store.confirmStorefront("GBR") == nil)
        #expect(store.image == nil && changes == 0)

        await store.confirmStorefront("CAN")?.value
        #expect(store.image != nil && changes == 1)
        let stored = directory.appendingPathComponent("minshawi-1954.jpg")
        #expect(try Data(contentsOf: stored) == bytes)
        #expect(try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)

        store.confirmStorefront(nil)
        #expect(store.image == nil && changes == 2)
        let reopened = RegionalMinshawiPortraitStore(directory: directory, expectedDigest: digest) {
            Issue.record("An eligible cached portrait should work offline")
            throw URLError(.notConnectedToInternet)
        }
        #expect(reopened.image == nil)
        reopened.confirmStorefront("USA")
        #expect(reopened.image != nil)
        reopened.confirmStorefront("MEX")
        #expect(reopened.image == nil)
        #expect(!FileManager.default.fileExists(atPath: stored.path))
    }

    @Test("Rejects a corrupted portrait on disk and a mismatched network reply")
    func invalidDigest() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let bytes = portraitBytes()
        let corrupt = bytes + Data([0xFF])
        try corrupt.write(to: directory.appendingPathComponent("minshawi-1954.jpg"))
        let store = RegionalMinshawiPortraitStore(directory: directory, expectedDigest: sha256(bytes)) { corrupt }
        await store.confirmStorefront("CAN")?.value
        #expect(store.image == nil)
    }

    @Test("Storefront changes invalidate both CarPlay thumbnails and Now Playing artwork")
    func rendererInvalidation() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let bytes = portraitBytes()
        let store = RegionalMinshawiPortraitStore(directory: directory, expectedDigest: sha256(bytes)) { bytes }
        let renderer = ChapterArtworkProvider(regionalPortrait: store, requestRegionalPortrait: {})
        let reciter = try #require(QuranFoundationCatalog().reciter(ReciterID("mp3quran.minshawi")))
        let surah = try #require(SurahCatalog.bundled().surah(104))
        func render() throws -> [Data] {
            let thumbnail = renderer.image(for: surah, reciter: reciter, language: .english,
                                           size: CGSize(width: 96, height: 96))
            let nowPlaying = renderer.nowPlayingArtwork(for: surah, reciter: reciter, language: .arabic)
            return [try #require(thumbnail.pngData()),
                    try #require(nowPlaying.image(at: CGSize(width: 256, height: 256))?.pngData())]
        }
        var visibleChanges = 0
        let token = renderer.objectWillChange.sink { visibleChanges += 1 }
        defer { token.cancel() }
        let fallback = try render()
        await store.confirmStorefront("CAN")?.value
        #expect(renderer.sourceKind(for: reciter.id) == .licensedPortrait)
        let enabled = try render()
        #expect(enabled[0] != fallback[0] && enabled[1] != fallback[1])
        store.confirmStorefront("FRA")
        #expect(renderer.sourceKind(for: reciter.id) == .typographyFallback)
        #expect(try render() == fallback)
        #expect(visibleChanges == 2)
    }

    @Test("A storefront change revokes a pending image, even if the transfer completes")
    func countryChangesDuringDownload() async {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let bytes = portraitBytes()
        let (events, continuation) = AsyncStream<Void>.makeStream()
        let (response, finish) = AsyncStream<Data>.makeStream()
        let store = RegionalMinshawiPortraitStore(directory: directory, expectedDigest: sha256(bytes)) {
            continuation.yield()
            for await data in response { return data }
            throw CancellationError()
        }
        let pending = store.confirmStorefront("CAN")
        var iterator = events.makeAsyncIterator()
        _ = await iterator.next()
        store.confirmStorefront("FRA")
        finish.yield(bytes)
        finish.finish()
        continuation.finish()
        await pending?.value
        #expect(store.image == nil)
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("minshawi-1954.jpg").path))
    }

    private func portraitBytes() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).jpegData(withCompressionQuality: 0.8) { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
    }

    private func sha256(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}
