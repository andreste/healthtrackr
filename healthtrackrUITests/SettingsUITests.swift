import XCTest

final class SettingsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func openSettings(_ app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["Discoveries"].waitForExistence(timeout: 10))
        element(AccessibilityID.settingsButton, in: app).tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    /// Swipe the settings List (UICollectionView in SwiftUI) to reveal content below the fold.
    private func scrollSettings(_ app: XCUIApplication) {
        app.collectionViews.firstMatch.swipeUp()
    }

    @MainActor
    func testSettingsSheetOpensAndCloses() {
        let app = launchApp()
        openSettings(app)

        // API Key section is near the top — visible without scrolling
        XCTAssertTrue(element(AccessibilityID.apiKeyTextField, in: app).waitForExistence(timeout: 5), "API key text field should be visible in settings")

        app.buttons["Done"].tap()

        XCTAssertTrue(app.navigationBars["Discoveries"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSettingsShowsSignOutButton() {
        let app = launchApp()
        openSettings(app)
        scrollSettings(app) // Account section is below the fold

        let signOutButton = element(AccessibilityID.signOutButton, in: app)
        XCTAssertTrue(signOutButton.waitForExistence(timeout: 5), "Sign Out button should be visible in settings")
    }

    @MainActor
    func testSettingsShowsHealthPermissionsSection() {
        let app = launchApp()
        openSettings(app)
        scrollSettings(app) // Health Permissions section is below the fold

        XCTAssertTrue(app.staticTexts["Sleep Analysis"].waitForExistence(timeout: 5), "Sleep Analysis permission should be visible")
        XCTAssertTrue(app.staticTexts["Heart Rate Variability"].waitForExistence(timeout: 3), "HRV permission should be visible")
        XCTAssertTrue(app.staticTexts["Steps"].waitForExistence(timeout: 3), "Steps permission should be visible")
        XCTAssertTrue(app.staticTexts["Resting Heart Rate"].waitForExistence(timeout: 3), "Resting Heart Rate permission should be visible")
    }

    @MainActor
    func testSettingsAPIKeyTextFieldExists() {
        let app = launchApp()
        openSettings(app)

        let apiKeyField = element(AccessibilityID.apiKeyTextField, in: app)
        XCTAssertTrue(apiKeyField.waitForExistence(timeout: 5), "API key text field should be visible in settings")
    }

    @MainActor
    func testSettingsViewCurrentHealthDataButtonExists() {
        let app = launchApp()
        openSettings(app)

        XCTAssertTrue(element(AccessibilityID.viewCurrentHealthDataButton, in: app).waitForExistence(timeout: 10), "View Current Health Data button should be visible in settings")
    }
}
