import SwiftUI
import QuranCarPlayerCore

/// A shared library and player that collapse to a navigation stack in compact windows.
struct RootView: View {
    let coordinator: PlaybackCoordinator
    let downloadManager: AudioDownloadManager?
    let artworkProvider: ChapterArtworkProvider
    @AppStorage(ListeningTheme.preferenceKey) private var preference = ListeningTheme.systemPreference
    @Environment(\.colorScheme) private var appearance
    private var theme: ListeningTheme { .resolve(preference, appearance: appearance) }
    @Environment(\.horizontalSizeClass) private var widthClass
    @Environment(\.verticalSizeClass) private var heightClass
    @State private var compactColumn: NavigationSplitViewColumn = .sidebar
    @State private var showSettings = false
    @State private var showReciters = false
    @State private var showDownloads = false

    private var language: ResolvedLanguage { coordinator.snapshot.language.resolved() }

    var body: some View {
        NavigationSplitView(preferredCompactColumn: $compactColumn) {
            SurahListView(coordinator: coordinator,
                          artworkProvider: artworkProvider,
                          language: language,
                          openPlayer: { compactColumn = .detail })
                .navigationTitle(L10n.string("surahs.title", language))
                .toolbar {
                    if widthClass == .regular {
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                recitersButton
                                libraryActions
                            } label: {
                                Label(L10n.string("theme.libraryActions", language), systemImage: "ellipsis")
                            }
                        }
                    } else {
                        ToolbarItem(placement: .topBarLeading) { recitersButton }
                        ToolbarItemGroup(placement: .topBarTrailing) { libraryActions }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if widthClass == .compact, coordinator.snapshot.currentRecording != nil {
                        MiniPlayerView(coordinator: coordinator,
                                       artworkProvider: artworkProvider,
                                       language: language) { compactColumn = .detail }
                    }
                }
        } detail: {
            if coordinator.currentSurah != nil {
                PlayerView(coordinator: coordinator, downloadManager: downloadManager,
                           artworkProvider: artworkProvider)
            } else {
                ContentUnavailableView {
                    Label(L10n.string("listen.nowPlaying", language), systemImage: "headphones")
                } description: {
                    Text(verbatim: L10n.string("theme.chooseSurah", language))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.background)
            }
        }
        .navigationSplitViewStyle(.balanced)
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
        .sheet(isPresented: $showDownloads) {
            if let downloadManager {
                NavigationStack {
                    DownloadsView(coordinator: coordinator, downloadManager: downloadManager)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(L10n.string("player.done", language)) {
                                    showDownloads = false
                                }
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView(coordinator: coordinator, downloadManager: downloadManager,
                             artworkProvider: artworkProvider,
                             previewLayout: heightClass == .compact ? .landscape :
                                 (widthClass == .regular ? .split : .portrait))
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L10n.string("player.done", language)) { showSettings = false }
                        }
                    }
            }
        }
        .environment(\.listeningTheme, theme)
        .tint(theme.accent)
        .background { ListeningWindowAppearance(theme: ListeningTheme(rawValue: preference)) }
        .environment(\.layoutDirection, language.isRightToLeft ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: language.localeIdentifier))
    }

    private var recitersButton: some View {
        Button { showReciters = true } label: {
            Label(L10n.string("reciters.title", language), systemImage: "person.wave.2")
        }
        .accessibilityHint(coordinator.selectedReciter?.displayName(for: language) ?? "")
    }

    @ViewBuilder
    private var libraryActions: some View {
        if downloadManager != nil {
            Button { showDownloads = true } label: {
                Label(L10n.string("downloads.title", language), systemImage: "arrow.down.circle")
            }
            .accessibilityHint(L10n.string("downloads.manage.hint", language))
        }
        Button { showSettings = true } label: {
            Label(L10n.string("settings.title", language), systemImage: "gearshape")
        }
    }
}

/// Compact bar showing the current surah and a play/pause control.
struct MiniPlayerView: View {
    let coordinator: PlaybackCoordinator
    @ObservedObject var artworkProvider: ChapterArtworkProvider
    @Environment(\.listeningTheme) private var theme
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
        .background(theme.surface)
        .overlay(alignment: .top) { Divider() }
    }

    private func titleText(_ snapshot: PlaybackSnapshot) -> String {
        guard let surah = coordinator.currentSurah else { return "" }
        return "\(surah.number). \(surah.displayName(for: language))"
    }
}
