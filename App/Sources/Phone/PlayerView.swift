import SwiftUI
import QuranCarPlayerCore

/// Full playback screen: title, reciter, status, seek slider, transport controls.
struct PlayerView: View {
    let coordinator: PlaybackCoordinator
    let downloadManager: AudioDownloadManager?
    @ObservedObject var artworkProvider: ChapterArtworkProvider
    @Environment(\.listeningTheme) private var theme

    @State private var isScrubbing = false
    @State private var scrubPosition: Double = 0

    private var language: ResolvedLanguage { coordinator.snapshot.language.resolved() }

    var body: some View {
        let snapshot = coordinator.snapshot
        GeometryReader { geometry in
            let horizontal = geometry.size.width > 580 && geometry.size.height < 500
            let coverSize = min(geometry.size.width * 0.72, geometry.size.height * 0.36, 340)
            ScrollView {
                VStack(spacing: 16) {
                    if snapshot.isTestAudio {
                        TestAudioBanner(language: language)
                    }
                    if horizontal {
                        HStack(spacing: 32) {
                            cover(side: max(100, min(geometry.size.height - 60, 280)))
                            controls(snapshot)
                        }
                    } else {
                        cover(side: coverSize)
                        controls(snapshot)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
                .frame(maxWidth: horizontal ? 880 : 460)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background {
            LinearGradient(colors: [theme.surface, theme.background], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
        .navigationTitle(L10n.string("listen.nowPlaying", language))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func cover(side: CGFloat) -> some View {
        if let surah = coordinator.currentSurah {
            let shape = RoundedRectangle(cornerRadius: 13)
            Image(uiImage: artworkProvider.image(for: surah, reciter: coordinator.currentReciter,
                                                 language: language, size: CGSize(width: 720, height: 720)))
                .resizable()
                .scaledToFit()
                .clipShape(shape)
                .background(theme.surface, in: shape)
                .overlay {
                    shape.strokeBorder(theme.accent.opacity(0.19), lineWidth: 1)
                }
                .frame(width: side, height: side)
                .shadow(color: .black.opacity(0.32), radius: 12, y: 6)
                .accessibilityHidden(true)
        }
    }

    private func controls(_ snapshot: PlaybackSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let surah = coordinator.currentSurah {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "\(surah.number). \(surah.displayName(for: language))")
                        .font(.largeTitle.bold())
                    Text(verbatim: surah.secondaryName(for: language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let reciter = coordinator.currentReciter {
                Label(reciter.displayName(for: language), systemImage: "person.wave.2")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if reciter.collection.id.provider == QuranFoundationCatalog.providerKey {
                    Text(verbatim: L10n.string("source.quranFoundation", language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Divider()
            ViewThatFits(in: .horizontal) {
                HStack {
                    statusView(snapshot).fixedSize()
                    Spacer()
                    downloadControl(snapshot).fixedSize()
                }
                VStack(alignment: .leading) {
                    statusView(snapshot)
                    downloadControl(snapshot)
                }
            }
            seekView(snapshot)
            transportControls(snapshot)
                .frame(maxWidth: .infinity)
        }
        .padding(4)
    }

    @ViewBuilder
    private func downloadControl(_ snapshot: PlaybackSnapshot) -> some View {
        if let downloadManager, let recording = snapshot.currentRecording,
           downloadManager.state(for: recording) == .downloaded || downloadManager.canDownload(recording) {
            RecordingDownloadControl(downloadManager: downloadManager, recording: recording, language: language)
        }
    }

    @ViewBuilder
    private func statusView(_ snapshot: PlaybackSnapshot) -> some View {
        HStack(spacing: 8) {
            switch snapshot.transport {
            case .loading, .buffering, .retrying:
                ProgressView()
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            default:
                EmptyView()
            }
            Text(verbatim: L10n.status(for: snapshot, language: language))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: 24)
        .accessibilityElement(children: .combine)

        if case .failed = snapshot.transport {
            Button {
                coordinator.retry()
            } label: {
                Label(L10n.string("player.retry", language), systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private func seekView(_ snapshot: PlaybackSnapshot) -> some View {
        let duration = snapshot.duration
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { isScrubbing ? scrubPosition : min(snapshot.elapsed, duration ?? snapshot.elapsed) },
                    set: { scrubPosition = $0 }
                ),
                in: 0...(duration ?? max(snapshot.elapsed, 1)),
                onEditingChanged: { editing in
                    if editing {
                        scrubPosition = snapshot.elapsed
                        isScrubbing = true
                    } else {
                        isScrubbing = false
                        coordinator.seek(to: scrubPosition)
                    }
                }
            )
            .disabled(duration == nil || snapshot.currentRecording == nil)
            .accessibilityLabel(L10n.string("player.seek", language))

            HStack {
                Text(verbatim: L10n.time(isScrubbing ? scrubPosition : snapshot.elapsed, language: language))
                Spacer()
                Text(verbatim: L10n.time(duration, language: language))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private func transportControls(_ snapshot: PlaybackSnapshot) -> some View {
        HStack(spacing: 20) {
            Button {
                coordinator.previous()
            } label: {
                Image(systemName: "backward.end.fill").font(.title)
                    .frame(width: 56, height: 56)
            }
            .disabled(!snapshot.canSkipBackward)
            .accessibilityLabel(L10n.string("player.previous", language))

            Button {
                coordinator.togglePlayPause()
            } label: {
                Image(systemName: snapshot.isActivelyPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 60))
            }
            .disabled(snapshot.currentRecording == nil)
            .accessibilityIdentifier("player-play-pause")
            .accessibilityLabel(L10n.string(snapshot.isActivelyPlaying ? "player.pause" : "player.play", language))

            Button {
                coordinator.next()
            } label: {
                Image(systemName: "forward.end.fill").font(.title)
                    .frame(width: 56, height: 56)
            }
            .disabled(!snapshot.canSkipForward)
            .accessibilityLabel(L10n.string("player.next", language))
        }
    }
}

private struct RecordingDownloadControl: View {
    let downloadManager: AudioDownloadManager
    let recording: RecordingID
    let language: ResolvedLanguage

    var body: some View {
        switch downloadManager.state(for: recording) {
        case .notDownloaded:
            Button {
                downloadManager.download(recording)
            } label: {
                Label(L10n.string("download.action", language), systemImage: "arrow.down.circle")
            }
            .buttonStyle(.bordered)

        case .downloading(let progress):
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    if let progress {
                        ProgressView(value: progress)
                            .frame(maxWidth: 180)
                        Text(verbatim: "\(Int((progress * 100).rounded()))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView()
                        Text(verbatim: L10n.string("download.downloading", language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Button(L10n.string("player.cancel", language), role: .cancel) {
                    downloadManager.cancel(recording)
                }
                .font(.caption)
            }
            .accessibilityElement(children: .combine)

        case .downloaded:
            Menu {
                Button(L10n.string("download.remove", language), role: .destructive) {
                    downloadManager.remove(recording)
                }
            } label: {
                Label(L10n.string("download.availableOffline", language),
                      systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(.bordered)
            .tint(.green)

        case .failed:
            VStack(spacing: 8) {
                Label(L10n.string("download.failed", language),
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Button {
                    downloadManager.retry(recording)
                } label: {
                    Label(L10n.string("player.retry", language), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

struct TestAudioBanner: View {
    let language: ResolvedLanguage
    var body: some View {
        Label(L10n.string("testAudio.banner", language), systemImage: "waveform.badge.exclamationmark")
            .font(.footnote.weight(.medium))
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Color.orange.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("test-audio-banner")
    }
}
