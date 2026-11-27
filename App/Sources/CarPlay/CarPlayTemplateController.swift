import UIKit
import CarPlay
import QuranCarPlayerCore

/// Builds and maintains the CarPlay template hierarchy for one interface-controller
/// connection: a tab bar with Listen, Surahs, and Reciters, plus the shared Now Playing
/// template. Template and item instances are preserved for the life of the connection
/// so lists are not rebuilt (and reset) on every state change.
@MainActor
final class CarPlayTemplateController: NSObject, CPSessionConfigurationDelegate {
    private let interfaceController: CPInterfaceController
    private let coordinator: PlaybackCoordinator
    private let artworkProvider: ChapterArtworkProvider

    private var sessionConfiguration: CPSessionConfiguration?
    private var tabBar: CPTabBarTemplate?
    private var listenTemplate: CPListTemplate?
    private var surahsTemplate: CPListTemplate?
    private var recitersTemplate: CPListTemplate?
    private weak var chapterRangeTemplate: CPListTemplate?
    private var visibleChapterGroup: ClosedRange<Int>?
    private var chapterPage = 0
    private var reciterPage = 0

    /// One item per surah, created once. Index = surah number - 1.
    private var surahItems: [CPListItem] = []
    private var reciterItems: [ReciterID: CPListItem] = [:]

    private var observation: ObservationToken?
    private var lastSnapshot: PlaybackSnapshot?
    private var language: ResolvedLanguage

    /// Completion handler for an in-flight list selection. CarPlay shows a spinner until
    /// it is called; we call it when the selection becomes ready, fails, or is superseded.
    private var pendingSelectionCompletion: (() -> Void)?
    private var pendingSelectionRecording: RecordingID?
    private var pendingSelectionTimeout: DispatchWorkItem?
    private var shouldPresentNowPlayingWhenReady = false
    private var didReportFailure: PlaybackFailure?

    init(interfaceController: CPInterfaceController,
         coordinator: PlaybackCoordinator,
         artworkProvider: ChapterArtworkProvider) {
        self.interfaceController = interfaceController
        self.coordinator = coordinator
        self.artworkProvider = artworkProvider
        self.language = coordinator.snapshot.language.resolved()
        super.init()
    }

    // MARK: Lifecycle

    func start() {
        let maxItems = CPListTemplate.maximumItemCount
        let maxSections = CPListTemplate.maximumSectionCount
        let maxTabs = CPTabBarTemplate.maximumTabCount
        CarPlayDiagnostics.log("limits: maximumItemCount=\(maxItems) maximumSectionCount=\(maxSections) maximumTabCount=\(maxTabs)")

        sessionConfiguration = CPSessionConfiguration(delegate: self)
        buildSurahItems()
        buildReciterItems()

        let listen = CPListTemplate(title: L10n.string("listen.title", language), sections: [])
        listen.tabImage = UIImage(systemName: "play.circle")
        listenTemplate = listen

        let surahs = CPListTemplate(title: L10n.string("surahs.title", language), sections: surahSections())
        surahs.tabImage = UIImage(systemName: "list.number")
        surahsTemplate = surahs

        let reciters = CPListTemplate(title: L10n.string("reciters.title", language), sections: [])
        reciters.tabImage = UIImage(systemName: "person.wave.2")
        recitersTemplate = reciters
        updateReciterPage()

        let nowPlaying = CPNowPlayingTemplate.shared
        nowPlaying.isUpNextButtonEnabled = false
        nowPlaying.isAlbumArtistButtonEnabled = false

        var tabs: [CPTemplate] = [listen, surahs, reciters]
        if tabs.count > maxTabs {
            CarPlayDiagnostics.log("maximumTabCount \(maxTabs) is below the 3 designed tabs; truncating tabs")
            tabs = Array(tabs.prefix(maxTabs))
        }
        let tabBar = CPTabBarTemplate(templates: tabs)
        self.tabBar = tabBar
        interfaceController.setRootTemplate(tabBar, animated: false) { _, error in
            if let error { CarPlayDiagnostics.log("setRootTemplate failed: \(error)") }
        }

        observation = coordinator.addObserver { [weak self] snapshot in
            self?.apply(snapshot)
        }
    }

    func stop() {
        observation?.cancel()
        observation = nil
        sessionConfiguration = nil
        finishPendingSelection()
        tabBar = nil
        listenTemplate = nil
        surahsTemplate = nil
        recitersTemplate = nil
    }

    // MARK: Building items

    private func buildSurahItems() {
        surahItems = coordinator.surahCatalog.surahs.map { surah in
            let item = CPListItem(text: surahText(surah),
                                  detailText: surah.secondaryName(for: language),
                                  image: chapterImage(surah: surah, reciter: coordinator.selectedReciter))
            item.userInfo = surah.number
            item.playingIndicatorLocation = .trailing
            item.handler = { [weak self] _, completion in
                guard let self else { completion(); return }
                let expected = self.coordinator.selectedRecording(forSurah: surah.number)
                self.beginSelection(expecting: expected, presentNowPlaying: true, completion: completion)
                // The coordinator notifies observers synchronously; the selection resolves in `apply`.
                self.coordinator.selectSurah(surah.number)
            }
            return item
        }
    }

    private func buildReciterItems() {
        reciterItems = [:]
        for reciter in coordinator.audioCatalog.reciters {
            let item = CPListItem(text: reciter.displayName(for: language), detailText: reciter.collection.riwayah)
            item.userInfo = reciter.id.rawValue
            item.handler = { [weak self] _, completion in
                guard let self else { completion(); return }
                self.coordinator.selectReciter(reciter.id)
                // Reciter changes are immediate selections; no spinner needed.
                completion()
            }
            reciterItems[reciter.id] = item
        }
    }

    private func surahText(_ surah: Surah) -> String {
        "\(surah.number). \(surah.displayName(for: language))"
    }

    /// A single section also works on vehicles that allow only one section per template.
    private func surahSections() -> [CPListSection] {
        guard CPListTemplate.maximumSectionCount > 0 else { return [] }
        let browser = CarPlayChapterBrowser(maximumItems: CPListTemplate.maximumItemCount,
                                            hasCurrent: coordinator.currentSurah != nil)
        var items: [CPListItem] = []
        if browser.showsShortcut, let surah = coordinator.currentSurah {
            let shortcut = CPListItem(text: L10n.string("surahs.current", language),
                                      detailText: surahText(surah),
                                      image: chapterImage(surah: surah, reciter: coordinator.currentReciter))
            shortcut.handler = surahItems[surah.number - 1].handler
            items.append(shortcut)
        }
        if browser.showsAllChapters {
            items.append(contentsOf: surahItems)
        } else {
            for group in browser.groups {
                let first = coordinator.surahCatalog.surah(group.lowerBound)
                let last = coordinator.surahCatalog.surah(group.upperBound)
                let item = CPListItem(text: rangeTitle(group),
                                      detailText: [first, last].compactMap { $0?.displayName(for: language) }.joined(separator: " – "))
                item.accessoryType = .disclosureIndicator
                item.handler = { [weak self] _, completion in
                    guard let self else { completion(); return }
                    self.openChapterGroup(group, completion: completion)
                }
                items.append(item)
            }
        }
        let header = coordinator.selectedReciter.map {
            "\(L10n.string("reciter.label", language)): \($0.displayName(for: language))"
        }
        return [CPListSection(items: items, header: header, sectionIndexTitle: nil)]
    }

    private func rangeTitle(_ range: ClosedRange<Int>) -> String {
        "\(range.lowerBound)–\(range.upperBound)"
    }

    private func openChapterGroup(_ group: ClosedRange<Int>, completion: @escaping () -> Void) {
        let template = CPListTemplate(title: rangeTitle(group), sections: [])
        chapterRangeTemplate = template
        visibleChapterGroup = group
        chapterPage = 0
        updateChapterPage()
        interfaceController.pushTemplate(template, animated: true) { _, error in
            if let error { CarPlayDiagnostics.log("pushTemplate(chapters) failed: \(error)") }
            completion()
        }
    }

    private func updateChapterPage() {
        guard let template = chapterRangeTemplate, let group = visibleChapterGroup else { return }
        let pages = CarPlayChapterBrowser.pages(in: group, maximumItems: CPListTemplate.maximumItemCount)
        guard !pages.isEmpty else { return }
        chapterPage = min(chapterPage, pages.count - 1)
        let range = pages[chapterPage]
        let items = range.map { surahItems[$0 - 1] }
        let header = pages.count > 1 ? rangeTitle(range) : nil
        template.updateSections([CPListSection(items: items, header: header, sectionIndexTitle: nil)])
        setPageButtons(on: template, page: chapterPage, count: pages.count) { [weak self] page in
            self?.chapterPage = page
            self?.updateChapterPage()
        }
    }

    private func updateReciterPage() {
        guard let template = recitersTemplate else { return }
        let items = coordinator.audioCatalog.reciters.compactMap { reciterItems[$0.id] }
        guard !items.isEmpty, CPListTemplate.maximumItemCount > 0 else { return }
        let pages = CarPlayChapterBrowser.pages(in: 0...(items.count - 1), maximumItems: CPListTemplate.maximumItemCount)
        reciterPage = min(reciterPage, pages.count - 1)
        template.updateSections([CPListSection(items: Array(items[pages[reciterPage]]))])
        setPageButtons(on: template, page: reciterPage, count: pages.count) { [weak self] page in
            self?.reciterPage = page
            self?.updateReciterPage()
        }
    }

    private func setPageButtons(on template: CPListTemplate, page: Int, count: Int,
                                selectPage: @escaping (Int) -> Void) {
        var controls: [CPBarButton] = []
        if page > 0 {
            controls.append(CPBarButton(title: L10n.string("carplay.previousPage", language)) { _ in selectPage(page - 1) })
        }
        if page + 1 < count {
            controls.append(CPBarButton(title: L10n.string("carplay.nextPage", language)) { _ in selectPage(page + 1) })
        }
        template.trailingNavigationBarButtons = controls
    }

    func sessionConfiguration(_ sessionConfiguration: CPSessionConfiguration,
                              limitedUserInterfacesChanged limitedUserInterfaces: CPLimitableUserInterface) {
        surahsTemplate?.updateSections(surahSections())
        updateChapterPage()
        updateReciterPage()
    }

    private func listenSection(_ snapshot: PlaybackSnapshot) -> CPListSection {
        var items: [CPListItem] = []

        if case .failed(let failure) = snapshot.transport {
            let image = coordinator.currentSurah.map {
                chapterImage(surah: $0, reciter: coordinator.currentReciter)
            }
            let item = CPListItem(text: L10n.failureMessage(failure.reason, language),
                                  detailText: currentDescription(snapshot),
                                  image: image)
            item.accessoryType = .disclosureIndicator
            item.handler = { [weak self] _, completion in
                guard let self else { completion(); return }
                self.beginSelection(expecting: snapshot.currentRecording, presentNowPlaying: true, completion: completion)
                self.coordinator.retry()
            }
            items.append(item)
        }

        if let session = snapshot.resumableSession, !snapshot.isActivelyPlaying, snapshot.transport != .completed {
            let surahName = coordinator.surahCatalog.surah(session.recording.surahNumber)?.displayName(for: language) ?? ""
            let reciterName = coordinator.reciter(for: session)?.displayName(for: language) ?? ""
            let image = coordinator.surahCatalog.surah(session.recording.surahNumber).map {
                chapterImage(surah: $0, reciter: coordinator.reciter(for: session))
            }
            let item = CPListItem(text: L10n.string("listen.continue", language),
                                  detailText: "\(session.recording.surahNumber). \(surahName) · \(reciterName) · \(L10n.time(session.elapsedSeconds, language: language))",
                                  image: image)
            item.handler = { [weak self] _, completion in
                guard let self else { completion(); return }
                self.beginSelection(expecting: session.recording, presentNowPlaying: true, completion: completion)
                self.coordinator.continueListening()
            }
            items.append(item)
        }

        if snapshot.currentRecording != nil {
            let image = coordinator.currentSurah.map {
                chapterImage(surah: $0, reciter: coordinator.currentReciter)
            }
            let item = CPListItem(text: L10n.string("listen.nowPlaying", language),
                                  detailText: currentDescription(snapshot),
                                  image: image)
            item.accessoryType = .disclosureIndicator
            item.handler = { [weak self] _, completion in
                self?.pushNowPlaying()
                completion()
            }
            items.append(item)
        }

        if snapshot.currentRecording == nil || snapshot.transport == .completed {
            let item = CPListItem(text: L10n.string("listen.choose", language), detailText: nil)
            item.accessoryType = .disclosureIndicator
            item.handler = { [weak self] _, completion in
                guard let self, let tabBar = self.tabBar, let surahs = self.surahsTemplate else { completion(); return }
                tabBar.select(surahs)
                completion()
            }
            items.append(item)
        }

        return CPListSection(items: items)
    }

    private func currentDescription(_ snapshot: PlaybackSnapshot) -> String? {
        guard let surah = coordinator.currentSurah else { return nil }
        var parts = [surahText(surah)]
        if let reciter = coordinator.currentReciter { parts.append(reciter.displayName(for: language)) }
        if snapshot.isTestAudio { parts.append(L10n.string("testAudio.short", language)) }
        return parts.joined(separator: " · ")
    }

    // MARK: Applying state

    private func apply(_ snapshot: PlaybackSnapshot) {
        let previous = lastSnapshot
        lastSnapshot = snapshot

        let newLanguage = snapshot.language.resolved()
        if newLanguage != language {
            language = newLanguage
            relocalize()
        }

        // Playing indicator: only the current surah is marked.
        if previous?.currentSurahNumber != snapshot.currentSurahNumber || previous?.isActivelyPlaying != snapshot.isActivelyPlaying {
            for (index, item) in surahItems.enumerated() {
                let shouldPlay = (index + 1) == snapshot.currentSurahNumber
                if item.isPlaying != shouldPlay { item.isPlaying = shouldPlay }
            }
        }

        // Selected reciter indicator and list header.
        if previous?.selectedReciter != snapshot.selectedReciter || previous == nil {
            for (id, item) in reciterItems {
                let isSelected = id == snapshot.selectedReciter
                item.setAccessoryImage(isSelected ? UIImage(systemName: "checkmark") : nil)
                item.setDetailText(isSelected ? L10n.string("reciter.selected", language)
                                              : coordinator.audioCatalog.reciter(id)?.collection.riwayah)
            }
            for (index, item) in surahItems.enumerated() {
                guard let surah = coordinator.surahCatalog.surah(index + 1) else { continue }
                item.setImage(chapterImage(surah: surah, reciter: coordinator.selectedReciter))
            }
            surahsTemplate?.updateSections(surahSections())
        } else if previous?.currentSurahNumber != snapshot.currentSurahNumber {
            surahsTemplate?.updateSections(surahSections())
        }

        // Listen tab reflects resume / now playing / failure state.
        if previous == nil
            || previous?.transport != snapshot.transport
            || previous?.resumableSession != snapshot.resumableSession
            || previous?.currentRecording != snapshot.currentRecording {
            listenTemplate?.updateSections([listenSection(snapshot)])
        }

        resolveSelectionIfSettled(snapshot)
        reportFailureIfNeeded(snapshot)
    }

    private func relocalize() {
        for (index, item) in surahItems.enumerated() {
            guard let surah = coordinator.surahCatalog.surah(index + 1) else { continue }
            item.setText(surahText(surah))
            item.setDetailText(surah.secondaryName(for: language))
            item.setImage(chapterImage(surah: surah, reciter: coordinator.selectedReciter))
        }
        for (id, item) in reciterItems {
            if let reciter = coordinator.audioCatalog.reciter(id) {
                item.setText(reciter.displayName(for: language))
            }
        }
        listenTemplate?.tabTitle = L10n.string("listen.title", language)
        surahsTemplate?.tabTitle = L10n.string("surahs.title", language)
        recitersTemplate?.tabTitle = L10n.string("reciters.title", language)
        if let tabBar { tabBar.updateTemplates(tabBar.templates) }
        surahsTemplate?.updateSections(surahSections())
        updateReciterPage()
        updateChapterPage()
        if let snapshot = lastSnapshot { listenTemplate?.updateSections([listenSection(snapshot)]) }
    }

    private func chapterImage(surah: Surah, reciter: Reciter?) -> UIImage {
        artworkProvider.image(for: surah,
                              reciter: reciter,
                              language: language,
                              size: CGSize(width: 120, height: 120))
    }

    // MARK: Selection completion handling

    private func beginSelection(expecting recording: RecordingID?, presentNowPlaying: Bool, completion: @escaping () -> Void) {
        finishPendingSelection()
        pendingSelectionCompletion = completion
        pendingSelectionRecording = recording
        shouldPresentNowPlayingWhenReady = presentNowPlaying
        // Safety net: never leave CarPlay's spinner running indefinitely.
        let timeout = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.finishPendingSelection() }
        }
        pendingSelectionTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: timeout)
    }

    private func finishPendingSelection() {
        pendingSelectionTimeout?.cancel()
        pendingSelectionTimeout = nil
        pendingSelectionRecording = nil
        let completion = pendingSelectionCompletion
        pendingSelectionCompletion = nil
        completion?()
    }

    /// Complete the selection callback once the chosen recording is playing, paused,
    /// failed, or replaced by another selection.
    private func resolveSelectionIfSettled(_ snapshot: PlaybackSnapshot) {
        guard pendingSelectionCompletion != nil else { return }
        if let expected = pendingSelectionRecording, snapshot.currentRecording != expected {
            shouldPresentNowPlayingWhenReady = false
            finishPendingSelection()
            return
        }
        switch snapshot.transport {
        case .loading, .retrying, .buffering:
            return
        case .playing:
            finishPendingSelection()
            if shouldPresentNowPlayingWhenReady {
                shouldPresentNowPlayingWhenReady = false
                pushNowPlaying()
            }
        case .paused, .failed, .completed, .idle:
            shouldPresentNowPlayingWhenReady = false
            finishPendingSelection()
        }
    }

    private func pushNowPlaying() {
        let nowPlaying = CPNowPlayingTemplate.shared
        if interfaceController.topTemplate === nowPlaying { return }
        interfaceController.pushTemplate(nowPlaying, animated: true) { success, error in
            if let error { CarPlayDiagnostics.log("pushTemplate(NowPlaying) failed: \(error)") }
            if !success { CarPlayDiagnostics.log("pushTemplate(NowPlaying) was not successful") }
        }
    }

    // MARK: Errors

    /// Show an actionable alert once per failure, with Retry. Keeps selection context visible
    /// in the Listen tab as well, so recovery never requires the phone.
    private func reportFailureIfNeeded(_ snapshot: PlaybackSnapshot) {
        guard case .failed(let failure) = snapshot.transport else {
            didReportFailure = nil
            return
        }
        guard didReportFailure != failure, interfaceController.presentedTemplate == nil else { return }
        didReportFailure = failure

        let title = L10n.failureMessage(failure.reason, language)
        let detail = currentDescription(snapshot)
        let retry = CPAlertAction(title: L10n.string("player.retry", language), style: .default) { [weak self] _ in
            guard let self else { return }
            self.interfaceController.dismissTemplate(animated: true) { _, _ in }
            self.shouldPresentNowPlayingWhenReady = true
            self.coordinator.retry()
        }
        let cancel = CPAlertAction(title: L10n.string("player.cancel", language), style: .cancel) { [weak self] _ in
            self?.interfaceController.dismissTemplate(animated: true) { _, _ in }
        }
        let variants = detail.map { ["\(title)\n\($0)", title] } ?? [title]
        let alert = CPAlertTemplate(titleVariants: variants, actions: [retry, cancel])
        interfaceController.presentTemplate(alert, animated: true) { _, error in
            if let error { CarPlayDiagnostics.log("presentTemplate(alert) failed: \(error)") }
        }
    }

}

/// Prefer a flat catalog when it fits. Otherwise present ranges and use at most one
/// additional template, even if a head unit exposes just one or two rows.
struct CarPlayChapterBrowser {
    let showsShortcut: Bool
    let showsAllChapters: Bool
    let groups: [ClosedRange<Int>]

    init(maximumItems: Int, hasCurrent: Bool) {
        let limit = min(max(0, maximumItems), Surah.count + 1)
        showsShortcut = hasCurrent && limit > 1
        let availableRows = showsShortcut ? limit - 1 : limit
        showsAllChapters = Surah.count <= availableRows
        if showsAllChapters || availableRows == 0 {
            groups = []
        } else {
            let minimumGroupSize = (Surah.count + availableRows - 1) / availableRows
            groups = Self.pages(in: Surah.numberRange, maximumItems: max(limit, minimumGroupSize))
        }
    }

    static func pages(in group: ClosedRange<Int>, maximumItems: Int) -> [ClosedRange<Int>] {
        guard maximumItems > 0 else { return [] }
        let size = min(group.count, maximumItems)
        return stride(from: group.lowerBound, through: group.upperBound, by: size).map { start in
            start...min(start + size - 1, group.upperBound)
        }
    }
}
