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
    func testHealthMetricsShowsRecoverySection() {
        let app = launchApp()
        openHealthMetrics(app)
        XCTAssertTrue(app.navigationBars["Health Data"].waitForExistence(timeout: 5))
        // Section headers render .uppercased() so appear as "RECOVERY" in the accessibility tree
        XCTAssertTrue(app.staticTexts["RECOVERY"].waitForExistence(timeout: 10), "RECOVERY section header should be visible")
    }
}
