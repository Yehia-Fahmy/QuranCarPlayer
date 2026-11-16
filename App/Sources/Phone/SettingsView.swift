import SwiftUI
import QuranCarPlayerCore

struct SettingsView: View {
    let coordinator: PlaybackCoordinator
    let downloadManager: AudioDownloadManager?

    private var language: ResolvedLanguage { coordinator.snapshot.language.resolved() }

    var body: some View {
        let snapshot = coordinator.snapshot
        Form {
            Section(L10n.string("settings.language", language)) {
                Picker(L10n.string("settings.language", language),
                       selection: Binding(get: { snapshot.language }, set: { coordinator.setLanguage($0) })) {
                    Text(verbatim: L10n.string("language.system", language)).tag(LanguagePreference.system)
                    Text(verbatim: L10n.string("language.english", language)).tag(LanguagePreference.english)
                    Text(verbatim: L10n.string("language.arabic", language)).tag(LanguagePreference.arabic)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section {
                Toggle(L10n.string("settings.autoResume", language),
                       isOn: Binding(get: { snapshot.automaticCarPlayResume },
                                     set: { coordinator.setAutomaticCarPlayResume($0) }))
            } header: {
                Text(verbatim: L10n.string("settings.carplay", language))
            } footer: {
                Text(verbatim: L10n.string("settings.autoResume.footer", language))
            }

            Section(L10n.string("settings.source", language)) {
                let usesTestTones = coordinator.audioCatalog.reciters.allSatisfy { $0.collection.isTestFixture }
                let sourceKey = usesTestTones
                    ? "settings.source.fixture"
                    : (downloadManager == nil
                       ? "settings.source.mp3quran.streamingOnly"
                       : "settings.source.mp3quran")
                Text(verbatim: L10n.string(sourceKey, language))
                    .font(.footnote)
                ForEach(coordinator.audioCatalog.reciters) { reciter in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: reciter.displayName(for: language)).font(.subheadline)
                        Text(verbatim: reciter.collection.attribution).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Section(L10n.string("settings.artwork", language)) {
                Text(verbatim: L10n.string("settings.artwork.footer", language))
                    .font(.footnote)
                ForEach(ChapterArtworkProvider.attributions) { attribution in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: attribution.title)
                            .font(.subheadline)
                        Text(verbatim: attribution.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Link(L10n.string("settings.artwork.source", language),
                                 destination: attribution.sourceURL)
                            Link(L10n.string("settings.artwork.license", language),
                                 destination: attribution.licenseURL)
                        }
                        .font(.caption)
                    }
                }
            }

            if let downloadManager,
               !coordinator.audioCatalog.reciters.allSatisfy({ $0.collection.isTestFixture }) {
                Section {
                    NavigationLink {
                        DownloadsView(coordinator: coordinator, downloadManager: downloadManager)
                    } label: {
                        LabeledContent(L10n.string("downloads.manage", language),
                                       value: downloadSummary)
                    }
                } header: {
                    Text(verbatim: L10n.string("downloads.title", language))
                } footer: {
                    Text(verbatim: L10n.string("downloads.footer", language))
                }
            }

            Section(L10n.string("settings.legal", language)) {
                Link(L10n.string("settings.privacyPolicy", language), destination: AppLegalURLs.privacyPolicy)
                Link(L10n.string("settings.support", language), destination: AppLegalURLs.support)
            }

            Section(L10n.string("settings.about", language)) {
                LabeledContent(L10n.string("settings.version", language), value: versionString)
            }
        }
        .navigationTitle(L10n.string("settings.title", language))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var versionString: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(short) (\(build))"
    }

    private var downloadSummary: String {
        guard let summary = downloadManager?.storageSummary else { return "" }
        let bytes = ByteCountFormatter.string(fromByteCount: summary.byteCount, countStyle: .file)
        return "\(summary.fileCount) · \(bytes)"
    }
}
