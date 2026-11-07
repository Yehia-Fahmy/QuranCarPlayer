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
