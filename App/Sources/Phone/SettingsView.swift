import SwiftUI
import QuranCarPlayerCore

struct SettingsView: View {
    let coordinator: PlaybackCoordinator

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
                Text(verbatim: L10n.string("settings.source.fixture", language))
                    .font(.footnote)
                ForEach(coordinator.audioCatalog.reciters) { reciter in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: reciter.displayName(for: language)).font(.subheadline)
                        Text(verbatim: reciter.collection.attribution).font(.caption).foregroundStyle(.secondary)
                    }
                }
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
}
