import Testing
import QuranCarPlayerCore
@testable import QuranCarPlayer

struct CarPlayChapterBrowserTests {
    @Test("All 114 chapters stay reachable within each vehicle's total row limit")
    func allChaptersAreReachable() {
        for limit in [1, 2, 5, 9, 12, 24, 113, 114, 115, Int.max] {
            for hasCurrent in [false, true] {
                let browser = CarPlayChapterBrowser(maximumItems: limit, hasCurrent: hasCurrent)
                let rootRows = browser.showsAllChapters ? Surah.count : browser.groups.count
                #expect(rootRows + (browser.showsShortcut ? 1 : 0) <= limit)
                if browser.showsAllChapters { continue }
                let pages = browser.groups.flatMap {
                    CarPlayChapterBrowser.pages(in: $0, maximumItems: limit)
                }
                #expect(pages.allSatisfy { $0.count <= limit })
                #expect(pages.flatMap { Array($0) } == Array(Surah.numberRange))
            }
        }
    }

    @Test("A full-size vehicle shows the current shortcut and flat Quran-ordered list")
    func fullCatalogWithShortcut() {
        let browser = CarPlayChapterBrowser(maximumItems: 115, hasCurrent: true)
        #expect(browser.showsAllChapters)
        #expect(browser.showsShortcut)
    }
}
