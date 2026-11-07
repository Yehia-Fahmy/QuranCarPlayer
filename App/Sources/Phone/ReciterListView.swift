import SwiftUI
import QuranCarPlayerCore

/// Short reciter list. Selecting one follows the shared coordinator rules
/// (restart current surah at zero; stay paused if paused).
struct ReciterListView: View {
    let coordinator: PlaybackCoordinator
    let language: ResolvedLanguage

    var body: some View {
        let selected = coordinator.snapshot.selectedReciter
        List(coordinator.audioCatalog.reciters) { reciter in
            Button {
                coordinator.selectReciter(reciter.id)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: reciter.displayName(for: language))
                            .font(.body)
                        Text(verbatim: reciter.collection.riwayah)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if reciter.id == selected {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                            .accessibilityLabel(L10n.string("reciter.selected", language))
                    }
                }
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier("reciter-\(reciter.id.rawValue)")
        }
        .listStyle(.insetGrouped)
    }
}
