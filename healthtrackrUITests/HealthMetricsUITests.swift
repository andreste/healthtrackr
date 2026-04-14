import XCTest

final class HealthMetricsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func openHealthMetrics(_ app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["Discoveries"].waitForExistence(timeout: 10))
        element(AccessibilityID.settingsButton, in: app).tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        element(AccessibilityID.viewCurrentHealthDataButton, in: app).tap()
    }

    @MainActor
    func testHealthMetricsNavigationTitle() {
        let app = launchApp()
        openHealthMetrics(app)
        XCTAssertTrue(app.navigationBars["Health Data"].waitForExistence(timeout: 5), "Navigation title should say 'Health Data'")
    }

    @MainActor
    func testHealthMetricsShowsSleepRow() {
        let app = launchApp()
        openHealthMetrics(app)
        XCTAssertTrue(app.navigationBars["Health Data"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Sleep"].exists, "Sleep metric row should be visible")
    }
}
