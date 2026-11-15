import SwiftUI
import QuranCarPlayerCore

/// Phone root: surah list with a compact player, reciter picker, and settings.
struct RootView: View {
    let coordinator: PlaybackCoordinator
    let downloadManager: AudioDownloadManager?
    let artworkProvider: ChapterArtworkProvider
    @State private var showPlayer = false
    @State private var showSettings = false
    @State private var showReciters = false

    private var language: ResolvedLanguage { coordinator.snapshot.language.resolved() }

    var body: some View {
        NavigationStack {
            SurahListView(coordinator: coordinator,
                          artworkProvider: artworkProvider,
                          language: language,
                          openPlayer: { showPlayer = true })
                .navigationTitle(L10n.string("surahs.title", language))
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showReciters = true
                        } label: {
                            Label(L10n.string("reciters.title", language), systemImage: "person.wave.2")
                        }
                        .accessibilityHint(coordinator.selectedReciter?.displayName(for: language) ?? "")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showSettings = true
                        } label: {
                            Label(L10n.string("settings.title", language), systemImage: "gearshape")
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if coordinator.snapshot.currentRecording != nil {
                        MiniPlayerView(coordinator: coordinator,
                                       artworkProvider: artworkProvider,
                                       language: language) { showPlayer = true }
                    }
                }
        }
        .sheet(isPresented: $showPlayer) {
            PlayerView(coordinator: coordinator,
                       downloadManager: downloadManager,
                       artworkProvider: artworkProvider)
        }
        .sheet(isPresented: $showReciters) {
            NavigationStack {
                ReciterListView(coordinator: coordinator, language: language)
                    .navigationTitle(L10n.string("reciters.title", language))
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L10n.string("player.done", language)) { showReciters = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView(coordinator: coordinator, downloadManager: downloadManager)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L10n.string("player.done", language)) { showSettings = false }
                        }
                    }
            }
        }
        .environment(\.layoutDirection, language.isRightToLeft ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: language.localeIdentifier))
    }
}

/// Compact bar showing the current surah and a play/pause control.
struct MiniPlayerView: View {
    let coordinator: PlaybackCoordinator
    let artworkProvider: ChapterArtworkProvider
    let language: ResolvedLanguage
    let open: () -> Void

    var body: some View {
        let snapshot = coordinator.snapshot
        HStack(spacing: 12) {
            Button(action: open) {
                HStack(spacing: 12) {
                    if let surah = coordinator.currentSurah {
                        Image(uiImage: artworkProvider.image(
                            for: surah,
                            reciter: coordinator.currentReciter,
                            language: language,
                            size: CGSize(width: 96, height: 96)
                        ))
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: titleText(snapshot))
                            .font(.headline)
                            .lineLimit(1)
                        Text(verbatim: L10n.status(for: snapshot, language: language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                coordinator.togglePlayPause()
            } label: {
                Image(systemName: snapshot.isActivelyPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(L10n.string(snapshot.isActivelyPlaying ? "player.pause" : "player.play", language))
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private func titleText(_ snapshot: PlaybackSnapshot) -> String {
        guard let surah = coordinator.currentSurah else { return "" }
        return "\(surah.number). \(surah.displayName(for: language))"
    }
}
