import Foundation
import Testing
@testable import QuranCarPlayerCore

@Suite("Surah catalog")
struct SurahCatalogTests {
    @Test("Bundled catalog has exactly 114 sequential surahs with bilingual names")
    func bundledCatalogIsValid() throws {
        let catalog = try SurahCatalog.bundled()
        #expect(catalog.surahs.count == 114)
        #expect(catalog.surahs.map(\.number) == Array(1...114))
        #expect(Set(catalog.surahs.map(\.arabicName)).count == 114)
        #expect(Set(catalog.surahs.map(\.transliteratedName)).count == 114)
        #expect(catalog.surah(1)?.transliteratedName == "Al-Fatihah")
        #expect(catalog.surah(114)?.arabicName == "الناس")
        #expect(catalog.surah(0) == nil)
        #expect(catalog.surah(115) == nil)
    }

    @Test("Validation rejects wrong counts and gaps")
    func validationRejectsBadData() throws {
        let good = try SurahCatalog.bundled().surahs
        #expect(throws: SurahCatalogError.wrongCount(113)) {
            try SurahCatalog(surahs: Array(good.dropLast()))
        }
        var gapped = good
        gapped[5] = Surah(number: 99, arabicName: "x", transliteratedName: "x", englishMeaning: "x")
        #expect(throws: SurahCatalogError.nonSequentialNumbers) {
            try SurahCatalog(surahs: gapped)
        }
    }

    @Test("Display names follow the resolved language")
    func displayNames() throws {
        let surah = try #require(try SurahCatalog.bundled().surah(18))
        #expect(surah.displayName(for: .english) == "Al-Kahf")
        #expect(surah.displayName(for: .arabic) == "الكهف")
        #expect(surah.secondaryName(for: .english) == "The Cave")
    }

    @Test("System language resolution")
    func languageResolution() {
        #expect(LanguagePreference.system.resolved(systemLanguageCodes: ["ar-EG", "en"]) == .arabic)
        #expect(LanguagePreference.system.resolved(systemLanguageCodes: ["en-CA"]) == .english)
        #expect(LanguagePreference.system.resolved(systemLanguageCodes: []) == .english)
        #expect(LanguagePreference.arabic.resolved(systemLanguageCodes: ["en"]) == .arabic)
        #expect(ResolvedLanguage.arabic.isRightToLeft)
    }
}

@Suite("Fixture audio catalog")
struct FixtureCatalogTests {
    @Test("Every surah resolves for every fixture reciter, and fixtures are flagged as test audio")
    func allSurahsResolve() throws {
        let catalog = FixtureAudioCatalog(fixtureURLs: Fixtures.toneURLs)
        for reciter in catalog.reciters {
            for n in Surah.numberRange {
                let source = try catalog.source(for: RecordingID(collection: reciter.collection.id, surahNumber: n))
                #expect(source.isTestFixture)
                #expect(Fixtures.toneURLs.contains(source.url))
            }
            #expect(reciter.collection.isTestFixture)
            #expect(reciter.englishName.contains("not Quran"))
        }
    }

    @Test("Unavailable surahs and unknown collections throw")
    func unavailable() {
        let catalog = FixtureAudioCatalog(fixtureURLs: Fixtures.toneURLs, unavailableSurahs: [19])
        #expect(throws: AudioCatalogError.self) { try catalog.source(for: Fixtures.recording(19)) }
        let foreign = RecordingID(collection: RecordingCollectionID(provider: "other", collection: "x"), surahNumber: 1)
        #expect(throws: AudioCatalogError.self) { try catalog.source(for: foreign) }
    }
}

@Suite("Persistence")
struct PersistenceTests {
    @Test("File session store round-trips and clears")
    func fileStoreRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FileSessionStore(fileURL: dir.appendingPathComponent("session.json"))
        #expect(try store.load() == nil)

        let session = PlaybackSession(recording: Fixtures.recording(18), elapsedSeconds: 42.5,
                                      checkpointDate: Date(timeIntervalSince1970: 1_700_000_000),
                                      lastPauseReason: .carDisconnected)
        try store.save(SessionCheckpoint(session: session))
        let loaded = try #require(try store.load())
        #expect(loaded.version == SessionCheckpoint.currentVersion)
        #expect(loaded.session == session)

        try store.clear()
        #expect(try store.load() == nil)
    }

    @Test("Unknown checkpoint versions are discarded, not misread")
    func unknownVersionDiscarded() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FileSessionStore(fileURL: dir.appendingPathComponent("session.json"))
        let session = PlaybackSession(recording: Fixtures.recording(1), elapsedSeconds: 1, checkpointDate: Date())
        try store.save(SessionCheckpoint(version: 999, session: session))
        #expect(try store.load() == nil)
    }

    @Test("Settings store round-trips through UserDefaults")
    func settingsRoundTrip() {
        let suite = "QuranCarPlayerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsSettingsStore(defaults: defaults)
        #expect(store.load() == nil)
        let settings = AppSettings(preferredReciter: Fixtures.reciterB.id, language: .arabic,
                                   automaticCarPlayResume: false, surahListAnchor: 67)
        store.save(settings)
        #expect(store.load() == settings)
    }

    @Test("Retry policy honours delays and the recovery window")
    func retryPolicy() {
        let policy = RetryPolicy()
        #expect(policy.delay(forAttempt: 0, elapsedSinceFirstFailure: 0) == 1)
        #expect(policy.delay(forAttempt: 1, elapsedSinceFirstFailure: 1) == 2)
        #expect(policy.delay(forAttempt: 2, elapsedSinceFirstFailure: 3) == 4)
        #expect(policy.delay(forAttempt: 3, elapsedSinceFirstFailure: 7) == nil)
        #expect(policy.delay(forAttempt: 2, elapsedSinceFirstFailure: 17) == nil)
    }
}
