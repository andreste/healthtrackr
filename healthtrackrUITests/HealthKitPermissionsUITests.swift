import XCTest

final class HealthKitPermissionsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPermissionsViewAppearsWithCorrectLaunchArg() {
        let app = launchApp(showHealthKitPermissions: true)
        XCTAssertTrue(element(AccessibilityID.healthKitPermissionsView, in: app).waitForExistence(timeout: 5), "HealthKit permissions view should appear")
    }

    @MainActor
    func testGrantAccessButtonExists() {
        let app = launchApp(showHealthKitPermissions: true)
        XCTAssertTrue(element(AccessibilityID.healthKitPermissionsView, in: app).waitForExistence(timeout: 5))
        // Button label text is "Grant Access" — accessibility ID may not surface in XCUITest for disabled-capable buttons
        XCTAssertTrue(app.buttons["Grant Access"].waitForExistence(timeout: 5), "Grant Access button should be visible")
    }
}
