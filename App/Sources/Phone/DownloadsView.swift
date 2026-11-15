import SwiftUI
import QuranCarPlayerCore

/// Durable and active download inventory. All mutations go through AudioDownloadManager.
struct DownloadsView: View {
    let coordinator: PlaybackCoordinator
    let downloadManager: AudioDownloadManager

    @State private var pendingConfirmation: DownloadConfirmation?

    private var language: ResolvedLanguage { coordinator.snapshot.language.resolved() }

    var body: some View {
        let items = downloadManager.downloadItems
        let activeItems = items.filter { $0.state != .downloaded }
        let savedItems = items.filter { $0.state == .downloaded }

        List {
            storageSection

            if downloadManager.cleanupFailed {
                Section {
                    Label(L10n.string("downloads.cleanupFailed", language),
                          systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .accessibilityElement(children: .combine)
                }
            }

            if items.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label(L10n.string("downloads.empty.title", language),
                              systemImage: "arrow.down.circle")
                    } description: {
                        Text(verbatim: L10n.string("downloads.empty.description", language))
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            }

            if !activeItems.isEmpty {
                Section(L10n.string("downloads.active", language)) {
                    ForEach(activeItems) { item in
                        DownloadItemRow(item: item,
                                        coordinator: coordinator,
                                        downloadManager: downloadManager,
                                        language: language,
                                        requestRemoval: {
                                            pendingConfirmation = .remove(item)
                                        })
                    }
                }
            }

            if !savedItems.isEmpty {
                Section(L10n.string("downloads.saved", language)) {
                    ForEach(savedItems) { item in
                        DownloadItemRow(item: item,
                                        coordinator: coordinator,
                                        downloadManager: downloadManager,
                                        language: language,
                                        requestRemoval: {
                                            pendingConfirmation = .remove(item)
                                        })
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L10n.string("downloads.title", language))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !items.isEmpty || downloadManager.cleanupFailed {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("downloads.removeAll.short", language),
                           role: .destructive) {
                        pendingConfirmation = .removeAll
                    }
                    .accessibilityHint(L10n.string("downloads.removeAll.confirm", language))
                }
            }
        }
        .confirmationDialog(confirmationTitle,
                            isPresented: confirmationPresented,
                            titleVisibility: .visible) {
            switch pendingConfirmation {
            case .remove(let item):
                Button(L10n.string("download.remove", language), role: .destructive) {
                    downloadManager.remove(item.recording)
                    pendingConfirmation = nil
                }
            case .removeAll:
                Button(L10n.string("downloads.removeAll", language), role: .destructive) {
                    downloadManager.removeAll()
                    pendingConfirmation = nil
                }
            case nil:
                EmptyView()
            }
            Button(L10n.string("player.cancel", language), role: .cancel) {
                pendingConfirmation = nil
            }
        }
        .environment(\.layoutDirection, language.isRightToLeft ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: language.localeIdentifier))
    }

    private var storageSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "internaldrive")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: L10n.string("downloads.totalStorage", language))
                        .font(.headline)
                    Text(verbatim: itemCountText(downloadManager.storageSummary.fileCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(verbatim: formattedBytes(downloadManager.storageSummary.byteCount))
                    .font(.body.monospacedDigit())
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var confirmationPresented: Binding<Bool> {
        Binding(
            get: { pendingConfirmation != nil },
            set: { if !$0 { pendingConfirmation = nil } }
        )
    }

    private var confirmationTitle: String {
        switch pendingConfirmation {
        case .remove(let item):
            guard let surah = coordinator.surahCatalog.surah(item.recording.surahNumber) else {
                return L10n.string("download.remove.confirm", language)
            }
            return "\(L10n.string("download.remove.confirm", language)) \(surah.displayName(for: language))?"
        case .removeAll:
            return L10n.string("downloads.removeAll.confirm", language)
        case nil:
            return ""
        }
    }

    private func itemCountText(_ count: Int) -> String {
        String(format: L10n.string("downloads.itemCount", language), count)
    }

    private func formattedBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

private enum DownloadConfirmation {
    case remove(AudioDownloadItem)
    case removeAll
}

private struct DownloadItemRow: View {
    let item: AudioDownloadItem
    let coordinator: PlaybackCoordinator
    let downloadManager: AudioDownloadManager
    let language: ResolvedLanguage
    let requestRemoval: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: surahTitle)
                        .font(.headline)
                    Text(verbatim: reciterName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                if let byteCount = item.byteCount {
                    let size = ByteCountFormatter.string(fromByteCount: byteCount,
                                                         countStyle: .file)
                    Text(verbatim: size)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(L10n.string("downloads.itemSize", language))
                        .accessibilityValue(size)
                }
            }

            statusAndProgress

            HStack {
                Spacer()
                controls
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var statusAndProgress: some View {
        switch item.state {
        case .downloading(let progress):
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: L10n.string("download.downloading", language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let progress {
                    ProgressView(value: progress)
                        .accessibilityLabel(L10n.string("download.downloading", language))
                        .accessibilityValue("\(Int((progress * 100).rounded()))%")
                } else {
                    ProgressView()
                        .accessibilityLabel(L10n.string("download.downloading", language))
                }
            }
        case .downloaded:
            Label(L10n.string("download.availableOffline", language),
                  systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .failed(let failure):
            Label(failureText(failure), systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        case .notDownloaded:
            EmptyView()
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch item.state {
        case .downloading:
            Button(role: .cancel) {
                downloadManager.cancel(item.recording)
            } label: {
                Label(L10n.string("player.cancel", language), systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
        case .downloaded:
            Button(role: .destructive, action: requestRemoval) {
                Label(L10n.string("download.remove", language), systemImage: "trash")
            }
            .buttonStyle(.bordered)
        case .failed(let failure):
            if failure != .unavailable {
                Button {
                    downloadManager.retry(item.recording)
                } label: {
                    Label(L10n.string("player.retry", language), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
        case .notDownloaded:
            EmptyView()
        }
    }

    private var surahTitle: String {
        guard let surah = coordinator.surahCatalog.surah(item.recording.surahNumber) else {
            return "\(item.recording.surahNumber)"
        }
        return "\(surah.number). \(surah.displayName(for: language))"
    }

    private var reciterName: String {
        if let reciter = coordinator.audioCatalog.reciter(forCollection: item.recording.collection) {
            return reciter.displayName(for: language)
        }
        return String(format: L10n.string("downloads.unknownReciter", language),
                      item.recording.collection.collection)
    }

    private func failureText(_ failure: AudioDownloadFailure) -> String {
        switch failure {
        case .network: return L10n.string("downloads.error.network", language)
        case .storage: return L10n.string("downloads.error.storage", language)
        case .unavailable: return L10n.string("downloads.error.unavailable", language)
        }
    }
}
