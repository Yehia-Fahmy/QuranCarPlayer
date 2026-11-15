import SwiftUI
import QuranCarPlayerCore

/// Full playback screen: title, reciter, status, seek slider, transport controls.
struct PlayerView: View {
    let coordinator: PlaybackCoordinator
    let downloadManager: AudioDownloadManager?
    let artworkProvider: ChapterArtworkProvider
    @Environment(\.dismiss) private var dismiss

    @State private var isScrubbing = false
    @State private var scrubPosition: Double = 0

    private var language: ResolvedLanguage { coordinator.snapshot.language.resolved() }

    var body: some View {
        let snapshot = coordinator.snapshot
        NavigationStack {
            VStack(spacing: 24) {
                if snapshot.isTestAudio {
                    TestAudioBanner(language: language)
                }

                Spacer(minLength: 0)

                if let surah = coordinator.currentSurah {
                    Image(uiImage: artworkProvider.image(
                        for: surah,
                        reciter: coordinator.currentReciter,
                        language: language,
                        size: CGSize(width: 640, height: 640)
                    ))
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280, maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
                    .accessibilityHidden(true)
                }

                VStack(spacing: 8) {
                    if let surah = coordinator.currentSurah {
                        Text(verbatim: "\(surah.number). \(surah.displayName(for: language))")
                            .font(.title.weight(.semibold))
                            .multilineTextAlignment(.center)
                        Text(verbatim: surah.secondaryName(for: language))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(verbatim: L10n.string("state.idle", language))
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    if let reciter = coordinator.currentReciter {
                        Text(verbatim: reciter.displayName(for: language))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal)

                statusView(snapshot)

                if let downloadManager,
                   let recording = snapshot.currentRecording,
                   downloadManager.canDownload(recording) {
                    RecordingDownloadControl(downloadManager: downloadManager,
                                             recording: recording,
                                             language: language)
                }

                seekView(snapshot)

                transportControls(snapshot)

                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle(L10n.string("listen.nowPlaying", language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("player.done", language)) { dismiss() }
                }
            }
        }
        .environment(\.layoutDirection, language.isRightToLeft ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: language.localeIdentifier))
        .presentationDragIndicator(.visible)
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
        .padding(.horizontal)
    }

    private func transportControls(_ snapshot: PlaybackSnapshot) -> some View {
        HStack(spacing: 40) {
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
                    .font(.system(size: 72))
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
                    downloadManager.download(recording)
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
