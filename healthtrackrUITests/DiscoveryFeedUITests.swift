import XCTest

final class DiscoveryFeedUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDiscoveryFeedShowsNavigationTitle() {
        let app = launchApp()
        XCTAssertTrue(app.navigationBars["Discoveries"].waitForExistence(timeout: 10), "Navigation title should say Discoveries")
    }

    @MainActor
    func testDiscoveryFeedLoadsWithPatternCards() {
        let app = launchApp()
        XCTAssertTrue(app.navigationBars["Discoveries"].waitForExistence(timeout: 10), "Feed should load")

        let sleepCard = element(AccessibilityID.patternCard("sleep_hrv"), in: app)
        XCTAssertTrue(sleepCard.waitForExistence(timeout: 10), "Sleep + HRV pattern card should appear")

        let stepsCard = element(AccessibilityID.patternCard("steps_rhr"), in: app)
        XCTAssertTrue(stepsCard.waitForExistence(timeout: 10), "Steps + HR pattern card should appear")
    }

    @MainActor
    func testFilterChipsSwitchContent() {
        let app = launchApp()

        // Wait for cards to load
        let sleepCard = element(AccessibilityID.patternCard("sleep_hrv"), in: app)
        XCTAssertTrue(sleepCard.waitForExistence(timeout: 10))

        // Tap "Sleep" filter (raw value from DiscoveryFeedViewModel.Filter.sleep)
        let sleepFilter = element(AccessibilityID.filterChip("Sleep"), in: app)
        XCTAssertTrue(sleepFilter.waitForExistence(timeout: 5), "Sleep filter chip should exist")
        sleepFilter.tap()

        // Sleep card should still be visible
        XCTAssertTrue(sleepCard.waitForExistence(timeout: 5), "Sleep card should remain after filtering")

        // Steps card should be hidden — wait for it to disappear without sleep()
        let stepsCard = element(AccessibilityID.patternCard("steps_rhr"), in: app)
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: stepsCard)
        wait(for: [expectation], timeout: 5)

        // Tap "All" filter to restore
        let allFilter = element(AccessibilityID.filterChip("All"), in: app)
        allFilter.tap()

        XCTAssertTrue(element(AccessibilityID.patternCard("steps_rhr"), in: app).waitForExistence(timeout: 5), "Steps card should reappear after selecting All filter")
    }

    @MainActor
    func testEmptyFeedStateShowsEmptyView() {
        let app = launchApp(stubEmptyFeed: true)
        XCTAssertTrue(app.navigationBars["Discoveries"].waitForExistence(timeout: 10))

        // No pattern cards should be present
        XCTAssertFalse(element(AccessibilityID.patternCard("sleep_hrv"), in: app).exists, "No pattern cards should appear in empty state")

        // Empty state view should be present
        XCTAssertTrue(element("EmptyStateView", in: app).waitForExistence(timeout: 5), "Empty state view should be visible")
    }

    @MainActor
    func testHealthKitDeniedStateShowsDeniedView() {
        let app = launchApp(healthKitDenied: true)
        XCTAssertTrue(app.navigationBars["Discoveries"].waitForExistence(timeout: 10))

        XCTAssertFalse(element(AccessibilityID.patternCard("sleep_hrv"), in: app).exists, "No pattern cards should appear when HealthKit is denied")
    }
}
