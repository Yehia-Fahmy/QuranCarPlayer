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

    func testThemeSelectionPersistsAfterRelaunch() {
        func openSettings() {
            if !app.buttons["Settings"].isHittable {
                app.buttons["Library Options"].tap()
            }
            app.buttons["Settings"].tap()
        }

        openSettings()
        let themePicker = app.buttons["listening-theme"]
        themePicker.tap()
        let gallery = app.navigationBars["Theme"]
        XCTAssertTrue(gallery.waitForExistence(timeout: 5))
        let folio = app.buttons["Folio"]
        folio.tap()
        XCTAssertTrue(folio.isSelected)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Theme gallery"
        attachment.lifetime = .keepAlways
        add(attachment)
        gallery.buttons["BackButton"].tap()
        XCTAssertTrue(themePicker.label.contains("Folio") || themePicker.value as? String == "Folio")
        app.terminate()
        app.launch()
        openSettings()
        themePicker.tap()
        XCTAssertTrue(folio.waitForExistence(timeout: 5))
        XCTAssertTrue(folio.isSelected)
        let system = app.buttons["System Appearance"]
        system.tap()
        XCTAssertTrue(system.isSelected)
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
