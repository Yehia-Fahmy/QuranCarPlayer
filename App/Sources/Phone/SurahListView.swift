import SwiftUI
import QuranCarPlayerCore

/// All 114 surahs in Quran order. Restores the saved anchor (or the current surah)
/// when the list appears; the anchor is a stable surah ID, never a pixel offset.
struct SurahListView: View {
    let coordinator: PlaybackCoordinator
    let language: ResolvedLanguage
    let openPlayer: () -> Void

    @State private var didRestoreAnchor = false

    var body: some View {
        let snapshot = coordinator.snapshot
        ScrollViewReader { proxy in
            List {
                if let session = snapshot.resumableSession, !snapshot.isActivelyPlaying {
                    Section {
                        Button {
                            coordinator.continueListening()
                            openPlayer()
                        } label: {
                            ContinueListeningRow(coordinator: coordinator, session: session, language: language)
                        }
                    }
                }

                Section {
                    ForEach(coordinator.surahCatalog.surahs) { surah in
                        Button {
                            coordinator.selectSurah(surah.number)
                            openPlayer()
                        } label: {
                            SurahRow(surah: surah,
                                     language: language,
                                     isCurrent: snapshot.currentSurahNumber == surah.number,
                                     isPlaying: snapshot.currentSurahNumber == surah.number && snapshot.isActivelyPlaying)
                        }
                        .id(surah.number)
                        .accessibilityIdentifier("surah-\(surah.number)")
                    }
                } header: {
                    if let reciter = coordinator.selectedReciter {
                        Text(verbatim: "\(L10n.string("reciter.label", language)): \(reciter.displayName(for: language))")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .onAppear {
                guard !didRestoreAnchor, let anchor = coordinator.surahListAnchor else { return }
                didRestoreAnchor = true
                proxy.scrollTo(anchor, anchor: .center)
            }
        }
    }
}

struct SurahRow: View {
    let surah: Surah
    let language: ResolvedLanguage
    let isCurrent: Bool
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(verbatim: "\(surah.number)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 32, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: surah.displayName(for: language))
                    .font(.body)
                    .fontWeight(isCurrent ? .semibold : .regular)
                Text(verbatim: surah.secondaryName(for: language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isCurrent {
                Image(systemName: isPlaying ? "speaker.wave.2.fill" : "speaker.fill")
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct ContinueListeningRow: View {
    let coordinator: PlaybackCoordinator
    let session: PlaybackSession
    let language: ResolvedLanguage

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "play.circle.fill")
                .font(.title)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: L10n.string("listen.continue", language))
                    .font(.headline)
                Text(verbatim: detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(verbatim: L10n.time(session.elapsedSeconds, language: language))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        let surahName = coordinator.surahCatalog.surah(session.recording.surahNumber)?.displayName(for: language) ?? ""
        let reciterName = coordinator.reciter(for: session)?.displayName(for: language) ?? ""
        return "\(session.recording.surahNumber). \(surahName) · \(reciterName)"
    }
}
