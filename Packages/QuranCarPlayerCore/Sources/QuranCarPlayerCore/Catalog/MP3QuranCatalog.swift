import Foundation

public enum MP3QuranCatalogError: Error, Equatable {
    case resourceMissing
    case invalidSnapshot(String)
}

/// Last-known-good snapshot of four complete Hafs murattal collections from
/// MP3Quran's public v3 reciters API. Audio is streamed from the `server`
/// URL the API returned; files are not copied into the app.
///
/// Retrieved 2026-11-07 from `https://mp3quran.net/api/v3/reciters`.
/// Each chosen moshaf reports `surah_total` 114 and a surah list of 1...114.
/// MP3Quran's published copyright note allows any visitor or developer to use
/// links on the site. This catalog does not grant offline-download rights.
public struct MP3QuranCatalog: AudioCatalog {
    public static let providerKey = "mp3quran"
    public static let defaultReciterID = ReciterID("mp3quran.maher")

    public let reciters: [Reciter]
    private let servers: [RecordingCollectionID: URL]

    public static func bundled() throws -> MP3QuranCatalog {
        guard let url = Bundle.module.url(forResource: "mp3quran-catalog", withExtension: "json") else {
            throw MP3QuranCatalogError.resourceMissing
        }
        return try MP3QuranCatalog(data: Data(contentsOf: url))
    }

    public init(data: Data) throws {
        let snapshot = try JSONDecoder().decode(Snapshot.self, from: data)
        guard !snapshot.reciters.isEmpty else {
            throw MP3QuranCatalogError.invalidSnapshot("no reciters")
        }
        var reciters: [Reciter] = []
        var servers: [RecordingCollectionID: URL] = [:]
        var seenIDs = Set<String>()
        for row in snapshot.reciters {
            guard seenIDs.insert(row.id).inserted else {
                throw MP3QuranCatalogError.invalidSnapshot("duplicate reciter \(row.id)")
            }
            guard !row.arabicName.isEmpty, !row.englishName.isEmpty else {
                throw MP3QuranCatalogError.invalidSnapshot("empty name for \(row.id)")
            }
            guard let server = URL(string: row.server),
                  server.scheme == "https",
                  server.host != nil,
                  row.server.hasSuffix("/") else {
                throw MP3QuranCatalogError.invalidSnapshot("server must be an https directory URL: \(row.server)")
            }
            let collectionID = RecordingCollectionID(provider: MP3QuranCatalog.providerKey, collection: String(row.moshafId))
            let collection = RecordingCollection(
                id: collectionID,
                riwayah: "\(row.riwayah) · \(row.style)",
                attribution: "Streamed from MP3Quran (mp3quran.net). \(row.englishName), \(row.riwayah), \(row.style). Moshaf \(row.moshafId).",
                isTestFixture: false
            )
            reciters.append(Reciter(id: ReciterID(row.id),
                                     arabicName: row.arabicName,
                                     englishName: row.englishName,
                                     collection: collection))
            servers[collectionID] = server
        }
        guard reciters.contains(where: { $0.id == MP3QuranCatalog.defaultReciterID }) else {
            throw MP3QuranCatalogError.invalidSnapshot("missing default reciter")
        }
        self.reciters = reciters
        self.servers = servers
    }

    /// `{server}{surah padded to 3 digits}.mp3`, using only the stored server URL.
    public func source(for recording: RecordingID) throws -> RecordingSource {
        guard let server = servers[recording.collection] else {
            throw AudioCatalogError.recordingUnavailable(recording)
        }
        let file = String(format: "%03d.mp3", recording.surahNumber)
        guard let url = URL(string: file, relativeTo: server)?.absoluteURL else {
            throw AudioCatalogError.recordingUnavailable(recording)
        }
        return RecordingSource(id: recording, url: url, isTestFixture: false)
    }
}

private struct Snapshot: Decodable {
    let reciters: [Row]
}

private struct Row: Decodable {
    let id: String
    let providerReciterId: Int
    let moshafId: Int
    let arabicName: String
    let englishName: String
    let riwayah: String
    let style: String
    let server: String
}
