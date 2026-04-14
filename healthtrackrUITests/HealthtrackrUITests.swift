import XCTest

final class HealthtrackrUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Sign In Screen

    @MainActor
    func testSignInScreenAppearsWhenNotAuthenticated() {
        let app = launchApp(skipAuth: false)
        let signInView = element(AccessibilityID.signInView, in: app)
        XCTAssertTrue(signInView.waitForExistence(timeout: 5), "Sign-in screen should appear when not authenticated")
        XCTAssertTrue(app.staticTexts["healthtrackr"].exists, "App title should be visible")
    }

    // MARK: - Launch Performance

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments.append("--uitesting")
            app.launchArguments.append("--skip-auth")
            app.launch()
        }
    }
}
