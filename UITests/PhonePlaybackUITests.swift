import XCTest

/// Phone flows on the iOS Simulator. CarPlay is not covered here.
final class PhonePlaybackUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-QCPUITestReset"]
        app.launch()
    }

    func testSurahListShowsTestReciterAndAllSurahsRemainReachable() {
        XCTAssertTrue(app.navigationBars["Surahs"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Reciter: Test Tone A (not Quran)"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["surah-1"].exists)
        let last = app.buttons["surah-114"]
        var attempts = 0
        while !last.isHittable && attempts < 30 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(last.isHittable, "surah 114 was not reachable after \(attempts) swipes")
    }

    func testSelectingASurahOpensThePlayerWithTestAudio() {
        app.buttons["surah-1"].tap()
        XCTAssertTrue(app.staticTexts["1. Al-Fatihah"].waitForExistence(timeout: 5))
        let banner = app.descendants(matching: .any)["test-audio-banner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Test Tone A (not Quran)"].exists)

        let transport = app.buttons["player-play-pause"]
        XCTAssertTrue(transport.waitForExistence(timeout: 5))
        // Selecting a surah starts playback, so the control is Pause.
        XCTAssertTrue(transport.wait(for: \.label, toEqual: "Pause", timeout: 8))
        transport.tap()
        XCTAssertTrue(transport.wait(for: \.label, toEqual: "Play", timeout: 8))

        app.buttons["Next surah"].tap()
        XCTAssertTrue(app.staticTexts["2. Al-Baqarah"].waitForExistence(timeout: 5))
    }

    func testSourcesOpenFromSettings() {
        app.buttons["Settings"].tap()
        let sources = app.buttons["Sources"]
        if !sources.isHittable { app.swipeUp() }
        XCTAssertFalse(app.staticTexts["Audio source"].exists)
        sources.tap()
        XCTAssertTrue(app.navigationBars["Sources"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Audio source"].exists)
        XCTAssertTrue(app.staticTexts["Reciter portrait sources"].exists)
        app.navigationBars["Sources"].buttons["BackButton"].tap()
        XCTAssertTrue(sources.waitForExistence(timeout: 5))
    }

    private func openSettings() {
        if !app.buttons["Settings"].isHittable { app.buttons["Library Options"].tap() }
        app.buttons["Settings"].tap()
    }

    private var carousel: XCUIElement { app.descendants(matching: .any)["theme-carousel"].firstMatch }
    private var confirmTheme: XCUIElement { app.buttons["confirm-theme"] }

    // Measure gestures inside the preview artwork. At accessibility text sizes
    // the carousel's full accessibility frame can extend below its scroll view.
    private func swipePreview(left: Bool) {
        let leading = carousel.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.15))
        let trailing = carousel.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.15))
        let start = left ? trailing : leading
        start.press(forDuration: 0.01, thenDragTo: left ? leading : trailing, withVelocity: .fast, thenHoldForDuration: 0)
    }

    private func openThemes() {
        openSettings()
        app.buttons["listening-theme"].tap()
        XCTAssertTrue(confirmTheme.waitForExistence(timeout: 5))
    }

    private func centerSystem() {
        let system = app.buttons["System Appearance"]
        for _ in 0..<5 {
            if system.exists && system.isSelected { break }
            swipePreview(left: false)
        }
        assertCentered("System Appearance")
        if confirmTheme.isEnabled { confirmTheme.tap() }
        XCTAssertFalse(confirmTheme.isEnabled)
    }

    private func assertCentered(_ name: String, line: UInt = #line) {
        let card = app.buttons[name]
        let aligned = NSPredicate { _, _ in
            card.exists && card.isSelected && abs(card.frame.midX - self.carousel.frame.midX) <= 3
        }
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: aligned, object: nil)], timeout: 5)
        if result != .completed {
            add(XCTAttachment(string: app.debugDescription))
            XCTFail("Expected \(name) at center. Card: \(card.debugDescription); carousel: \(carousel.frame)", line: line)
        }
    }

    func testThemeNeedsConfirmationAndSurvivesRelaunch() {
        openThemes()
        centerSystem()
        carousel.swipeLeft()
        assertCentered("Folio")
        XCTAssertTrue(confirmTheme.isEnabled)
        let back = app.descendants(matching: .any)["BackButton"].firstMatch
        back.tap()
        let row = app.buttons["listening-theme"]
        XCTAssertTrue(row.label.contains("System Appearance") || row.value as? String == "System Appearance")
        row.tap()
        assertCentered("System Appearance")
        carousel.swipeLeft()
        confirmTheme.tap()
        XCTAssertFalse(confirmTheme.isEnabled)
        XCTAssertEqual(app.buttons["Folio"].value as? String, "Applied")
        carousel.swipeLeft()
        assertCentered("Studio")
        app.terminate()
        app.launch()
        openThemes()
        assertCentered("Folio")
        XCTAssertFalse(confirmTheme.isEnabled)
        carousel.swipeRight()
        confirmTheme.tap()
        assertCentered("System Appearance")
    }

    func testRapidThemeSwipesKeepTitleAndAppliedAppearanceStable() {
        openThemes()
        centerSystem()
        let title = app.navigationBars["Theme"].staticTexts["Theme"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        let originalFrame = title.frame
        // Start at the first boundary, traverse every palette, overswipe the last
        // boundary, then reverse repeatedly across the light/dark palette boundary.
        swipePreview(left: false)
        for _ in 0..<6 { swipePreview(left: true) }
        assertCentered("Copper")
        for _ in 0..<3 {
            swipePreview(left: false)
            swipePreview(left: false)
            swipePreview(left: true)
            swipePreview(left: true)
        }
        assertCentered("Copper")
        XCTAssertTrue(confirmTheme.isEnabled)
        XCTAssertEqual(title.frame, originalFrame)
        let preview = XCTAttachment(screenshot: app.screenshot())
        preview.name = "Copper preview before confirmation"
        preview.lifetime = .keepAlways
        add(preview)
        for _ in 0..<6 { swipePreview(left: false) }
        assertCentered("System Appearance")
        XCTAssertEqual(title.frame, originalFrame)
        XCTAssertFalse(confirmTheme.isEnabled)
        XCTAssertEqual(app.buttons["System Appearance"].value as? String, "Applied")
    }

    func testPendingThemeSurvivesRotationAndAdjacentCardTap() {
        defer { XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .portrait
        openThemes()
        centerSystem()
        let visibleNeighbor = app.buttons["Folio"].frame.intersection(carousel.frame)
        XCTAssertFalse(visibleNeighbor.isEmpty)
        let origin = carousel.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: visibleNeighbor.midX - carousel.frame.minX,
                                   dy: visibleNeighbor.minY - carousel.frame.minY + 24)).tap()
        assertCentered("Folio")
        XCUIDevice.shared.orientation = .landscapeLeft
        assertCentered("Folio")
        XCTAssertTrue(confirmTheme.isEnabled && confirmTheme.isHittable)
        swipePreview(left: true)
        swipePreview(left: true)
        assertCentered("Nocturne")
        confirmTheme.tap()
        XCTAssertFalse(confirmTheme.isEnabled)
        XCUIDevice.shared.orientation = .portrait
        assertCentered("Nocturne")
        XCTAssertEqual(app.buttons["Nocturne"].value as? String, "Applied")
        centerSystem()
    }

    func testArabicThemeConfirmationAndSwipeDirection() {
        openSettings()
        app.buttons["العربية"].tap()
        app.buttons["listening-theme"].tap()
        let system = app.buttons["مظهر النظام"]
        for _ in 0..<5 {
            if system.exists && system.isSelected { break }
            carousel.swipeLeft(velocity: .fast)
        }
        assertCentered("مظهر النظام")
        if confirmTheme.isEnabled { confirmTheme.tap() }
        carousel.swipeRight(velocity: .fast)
        assertCentered("ورق")
        XCTAssertEqual(confirmTheme.label, "تأكيد المظهر")
        XCTAssertTrue(confirmTheme.isEnabled)
        carousel.swipeLeft(velocity: .fast)
        assertCentered("مظهر النظام")
        XCTAssertFalse(confirmTheme.isEnabled)
    }

    func testReciterChangeAndSettingsLanguage() {
        app.buttons["Reciters"].tap()
        let toneB = app.buttons["reciter-fixture.toneB"]
        XCTAssertTrue(toneB.waitForExistence(timeout: 5))
        toneB.tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Reciter: Test Tone B (not Quran)"].waitForExistence(timeout: 5))

        app.buttons["Settings"].tap()
        let arabic = app.buttons["العربية"]
        XCTAssertTrue(arabic.waitForExistence(timeout: 5))
        arabic.tap()
        XCTAssertTrue(app.staticTexts["الإعدادات"].waitForExistence(timeout: 5))
        app.buttons["تم"].tap()
        XCTAssertTrue(app.staticTexts["السور"].waitForExistence(timeout: 5))
    }
}
