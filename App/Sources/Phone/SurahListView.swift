import SwiftUI
import QuranCarPlayerCore

/// All 114 surahs in Quran order. Restores the saved anchor (or the current surah)
/// when the list appears; the anchor is a stable surah ID, never a pixel offset.
struct SurahListView: View {
    @Environment(\.listeningTheme) private var theme
    let coordinator: PlaybackCoordinator
    let artworkProvider: ChapterArtworkProvider
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
                            ContinueListeningRow(coordinator: coordinator,
                                                 artworkProvider: artworkProvider,
                                                 session: session,
                                                 language: language)
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
                        .buttonStyle(.plain)
                        .listRowBackground(snapshot.currentSurahNumber == surah.number ? theme.accent.opacity(0.13) : theme.surface)
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
            .listeningListBackground(theme)
            .onAppear {
                guard !didRestoreAnchor, let anchor = coordinator.surahListAnchor else { return }
                didRestoreAnchor = true
                proxy.scrollTo(anchor, anchor: .center)
            }
        }
    }
}

struct SurahRow: View {
    @Environment(\.listeningTheme) private var theme
    let surah: Surah
    let language: ResolvedLanguage
    let isCurrent: Bool
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(verbatim: String(format: "%02d", surah.number))
                .font(.system(.subheadline, design: .monospaced, weight: .medium))
                .foregroundStyle(theme.accent)
                .frame(minWidth: 32, minHeight: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: surah.displayName(for: language))
                    .foregroundStyle(.primary)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(surah.number). \(surah.displayName(for: language)), \(surah.secondaryName(for: language))")
    }
}

struct ContinueListeningRow: View {
    let coordinator: PlaybackCoordinator
    @ObservedObject var artworkProvider: ChapterArtworkProvider
    let session: PlaybackSession
    let language: ResolvedLanguage

    var body: some View {
        HStack(spacing: 12) {
            if let surah = coordinator.surahCatalog.surah(session.recording.surahNumber) {
                Image(uiImage: artworkProvider.image(
                    for: surah,
                    reciter: coordinator.reciter(for: session),
                    language: language,
                    size: CGSize(width: 96, height: 96)
                ))
                .resizable()
                .scaledToFill()
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
            }
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
