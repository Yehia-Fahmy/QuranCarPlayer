#if canImport(AVFoundation)
import Foundation
import AVFoundation

/// `AudioEngine` backed by a single `AVPlayer`. Contains no playback policy.
///
/// All callbacks are forwarded on the main actor and tagged with the item they
/// concern so the coordinator can discard stale ones.
@MainActor
public final class AVPlayerEngine: AudioEngine {
    public var eventHandler: (@MainActor (AudioEngineEvent) -> Void)?

    private var player: AVPlayer
    private var playerItem: AVPlayerItem?
    private var currentID: EngineItemID?
    private var pendingStart: TimeInterval = 0
    private var hasReportedReady = false

    private var itemObservations: [NSKeyValueObservation] = []
    private var playerObservations: [NSKeyValueObservation] = []
    private var notificationTokens: [NSObjectProtocol] = []
    private var periodicObserver: Any?

    public let timeUpdateInterval: TimeInterval

    public init(timeUpdateInterval: TimeInterval = 0.5) {
        self.timeUpdateInterval = timeUpdateInterval
        self.player = AVPlayerEngine.makePlayer()
        attachPlayerObservers()
    }

    private static func makePlayer() -> AVPlayer {
        let player = AVPlayer()
        player.automaticallyWaitsToMinimizeStalling = true
        player.actionAtItemEnd = .pause
        return player
    }

    // MARK: AudioEngine

    public var currentTime: TimeInterval {
        let seconds = player.currentTime().seconds
        return seconds.isFinite ? max(0, seconds) : 0
    }

    public func load(_ item: EngineItem) {
        detachItem()
        currentID = item.id
        pendingStart = item.startAt
        hasReportedReady = false

        let asset = AVURLAsset(url: item.url)
        let newItem = AVPlayerItem(asset: asset)
        playerItem = newItem
        attachItemObservers(newItem, id: item.id)
        player.replaceCurrentItem(with: newItem)
    }

    public func play() {
        player.play()
    }

    public func pause() {
        player.pause()
    }

    public func seek(to time: TimeInterval) {
        guard let playerItem, let id = currentID else { return }
        let target = CMTime(seconds: max(0, time), preferredTimescale: 600)
        playerItem.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self, self.currentID == id else { return }
                    self.emit(.timeUpdated(id, self.currentTime))
                }
            }
        }
    }

    public func stop() {
        detachItem()
        player.replaceCurrentItem(with: nil)
    }

    /// Rebuild the player after a media-services reset. The caller reloads the item.
    public func recreatePlayer() {
        detachItem()
        detachPlayerObservers()
        player = AVPlayerEngine.makePlayer()
        attachPlayerObservers()
    }

    // MARK: Observation plumbing

    private func emit(_ event: AudioEngineEvent) {
        eventHandler?(event)
    }

    /// Hop to the main actor from KVO / completion callbacks that may arrive on any thread,
    /// preserving FIFO ordering of events.
    nonisolated private static func onMain(_ body: @escaping @MainActor () -> Void) {
        DispatchQueue.main.async { MainActor.assumeIsolated { body() } }
    }

    private func attachPlayerObservers() {
        playerObservations.append(player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            let status = player.timeControlStatus
            AVPlayerEngine.onMain { [weak self] in
                guard let self, let id = self.currentID, self.hasReportedReady else { return }
                switch status {
                case .waitingToPlayAtSpecifiedRate: self.emit(.buffering(id))
                case .playing: self.emit(.resumedPlaying(id))
                case .paused: break
                @unknown default: break
                }
            }
        })

        let interval = CMTime(seconds: timeUpdateInterval, preferredTimescale: 600)
        periodicObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self, let id = self.currentID, self.hasReportedReady, time.seconds.isFinite else { return }
                guard self.player.timeControlStatus == .playing else { return }
                self.emit(.timeUpdated(id, max(0, time.seconds)))
            }
        }
    }

    private func detachPlayerObservers() {
        playerObservations.forEach { $0.invalidate() }
        playerObservations.removeAll()
        if let periodicObserver {
            player.removeTimeObserver(periodicObserver)
            self.periodicObserver = nil
        }
    }

    private func attachItemObservers(_ item: AVPlayerItem, id: EngineItemID) {
        itemObservations.append(item.observe(\.status, options: [.new]) { [weak self] item, _ in
            let status = item.status
            let error = item.error
            AVPlayerEngine.onMain { [weak self] in
                guard let self, self.currentID == id else { return }
                switch status {
                case .readyToPlay: self.handleReady(item: item, id: id)
                case .failed: self.emit(.failed(id, AVPlayerEngine.classify(error, url: (item.asset as? AVURLAsset)?.url)))
                case .unknown: break
                @unknown default: break
                }
            }
        })

        itemObservations.append(item.observe(\.duration, options: [.new]) { [weak self] item, _ in
            let duration = item.duration
            AVPlayerEngine.onMain { [weak self] in
                guard let self, self.currentID == id, self.hasReportedReady else { return }
                self.emit(.durationChanged(id, AVPlayerEngine.seconds(duration)))
            }
        })

        let center = NotificationCenter.default
        notificationTokens.append(center.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.currentID == id else { return }
                self.emit(.playedToEnd(id))
            }
        })
        notificationTokens.append(center.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] note in
            let error = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            MainActor.assumeIsolated {
                guard let self, self.currentID == id else { return }
                self.emit(.failed(id, AVPlayerEngine.classify(error, url: (item.asset as? AVURLAsset)?.url)))
            }
        })
        notificationTokens.append(center.addObserver(forName: .AVPlayerItemPlaybackStalled, object: item, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.currentID == id else { return }
                self.emit(.stalled(id))
            }
        })
    }

    private func detachItem() {
        itemObservations.forEach { $0.invalidate() }
        itemObservations.removeAll()
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
        notificationTokens.removeAll()
        playerItem = nil
        currentID = nil
        hasReportedReady = false
    }

    /// Seek to the requested start position before reporting ready, so playback never
    /// audibly starts from zero and then jumps.
    private func handleReady(item: AVPlayerItem, id: EngineItemID) {
        guard !hasReportedReady else { return }
        let duration = AVPlayerEngine.seconds(item.duration)
        let start = pendingStart
        pendingStart = 0
        if start > 0 {
            let clampedStart = duration.map { min(start, $0) } ?? start
            let target = CMTime(seconds: clampedStart, preferredTimescale: 600)
            item.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                AVPlayerEngine.onMain { [weak self] in
                    guard let self, self.currentID == id, !self.hasReportedReady else { return }
                    self.hasReportedReady = true
                    self.emit(.readyToPlay(id, duration: duration))
                }
            }
        } else {
            hasReportedReady = true
            emit(.readyToPlay(id, duration: duration))
        }
    }

    private static func seconds(_ time: CMTime) -> TimeInterval? {
        guard time.isNumeric, time.seconds.isFinite, time.seconds > 0 else { return nil }
        return time.seconds
    }

    // MARK: Error classification

    /// Maps player errors to coarse failure kinds. Unknown errors stay retriable but
    /// are bounded by the coordinator's retry policy.
    static func classify(_ error: Error?, url: URL?) -> EngineFailure {
        var chain: [NSError] = []
        var cursor = error as NSError?
        while let e = cursor, chain.count < 6 {
            chain.append(e)
            cursor = e.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        let message = chain.first?.localizedDescription ?? "Unknown playback error"

        for e in chain {
            switch e.domain {
            case NSURLErrorDomain:
                switch e.code {
                case NSURLErrorUserAuthenticationRequired, NSURLErrorUserCancelledAuthentication,
                     NSURLErrorNoPermissionsToReadFile, NSURLErrorClientCertificateRequired, NSURLErrorClientCertificateRejected:
                    return EngineFailure(kind: .notPermitted, message: message)
                case NSURLErrorFileDoesNotExist, NSURLErrorBadURL, NSURLErrorUnsupportedURL:
                    return EngineFailure(kind: .missingRecording, message: message)
                default:
                    return EngineFailure(kind: .network, message: message)
                }
            case "CoreMediaErrorDomain":
                // -12938 is CoreMedia's "file not found" for HTTP 404 responses.
                if e.code == -12938 { return EngineFailure(kind: .missingRecording, message: message) }
            case AVFoundationErrorDomain:
                switch AVError.Code(rawValue: e.code) {
                case .fileFormatNotRecognized?, .failedToParse?, .decoderNotFound?, .fileFailedToParse?, .undecodableMediaData?:
                    return EngineFailure(kind: .missingRecording, message: message)
                case .contentIsProtected?, .contentIsNotAuthorized?:
                    return EngineFailure(kind: .notPermitted, message: message)
                default:
                    break
                }
            default:
                break
            }
        }

        if let url, url.isFileURL {
            return EngineFailure(kind: .missingRecording, message: message)
        }
        return EngineFailure(kind: .unknown, message: message)
    }
}
#endif
