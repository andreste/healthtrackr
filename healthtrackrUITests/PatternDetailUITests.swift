import XCTest

final class PatternDetailUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTapPatternCardNavigatesToDetail() {
        let app = launchApp()

        let sleepCard = element(AccessibilityID.patternCard("sleep_hrv"), in: app)
        XCTAssertTrue(sleepCard.waitForExistence(timeout: 10))
        sleepCard.tap()

        let detailView = element(AccessibilityID.patternDetailView, in: app)
        XCTAssertTrue(detailView.waitForExistence(timeout: 5), "Pattern detail view should appear after tapping a card")

        XCTAssertTrue(app.staticTexts["WHAT THIS MEANS"].waitForExistence(timeout: 3), "Narration section header should be visible")
    }

    @MainActor
    func testPatternDetailBackNavigation() {
        let app = launchApp()

        let sleepCard = element(AccessibilityID.patternCard("sleep_hrv"), in: app)
        XCTAssertTrue(sleepCard.waitForExistence(timeout: 10))
        sleepCard.tap()

        XCTAssertTrue(element(AccessibilityID.patternDetailView, in: app).waitForExistence(timeout: 5))

        // Tap back
        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(app.navigationBars["Discoveries"].waitForExistence(timeout: 5), "Feed should reappear after navigating back")
    }

    @MainActor
    func testPatternDetailNarrationSectionIsVisible() {
        let app = launchApp()

        let sleepCard = element(AccessibilityID.patternCard("sleep_hrv"), in: app)
        XCTAssertTrue(sleepCard.waitForExistence(timeout: 10))
        sleepCard.tap()

        XCTAssertTrue(element(AccessibilityID.patternDetailView, in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["WHAT THIS MEANS"].waitForExistence(timeout: 5), "Narration section header should be visible")

        // Verify a narration body exists below the header
        XCTAssertTrue(
            app.staticTexts["When you sleep more than 7 hours, your heart rate variability tends to increase the next morning."].waitForExistence(timeout: 5),
            "Narration body text should be visible"
        )
    }

    @MainActor
    func testPatternDetailHeadlineIsVisible() {
        let app = launchApp()

        let sleepCard = element(AccessibilityID.patternCard("sleep_hrv"), in: app)
        XCTAssertTrue(sleepCard.waitForExistence(timeout: 10))
        sleepCard.tap()

        XCTAssertTrue(element(AccessibilityID.patternDetailView, in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts["Your HRV Rises After Longer Sleep"].waitForExistence(timeout: 5),
            "Pattern headline from StubNarrator should be visible"
        )
    }
}
