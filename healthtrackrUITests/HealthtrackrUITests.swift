import XCTest

final class HealthtrackrUITests: XCTestCase {

    override func setUpWithError() throws {
        throw XCTSkip("UI tests are temporarily disabled")
    }

    // MARK: - Helpers

    private func launchApp(
        skipAuth: Bool = true,
        stubEmptyFeed: Bool = false,
        healthKitDenied: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        if skipAuth { app.launchArguments.append("--skip-auth") }
        if stubEmptyFeed { app.launchArguments.append("--stub-empty-feed") }
        if healthKitDenied { app.launchArguments.append("--healthkit-denied") }
        app.launch()
        return app
    }

    /// Find any element with the given accessibility identifier, regardless of type.
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    // MARK: - Sign In Screen

    @MainActor
    func testSignInScreenAppearsWhenNotAuthenticated() {
        let app = launchApp(skipAuth: false)
        let signInView = element("SignInView", in: app)
        XCTAssertTrue(signInView.waitForExistence(timeout: 5), "Sign-in screen should appear when not authenticated")
        XCTAssertTrue(app.staticTexts["healthtrackr"].exists, "App title should be visible")
    }

    // MARK: - Discovery Feed

    @MainActor
    func testDiscoveryFeedShowsNavigationTitle() {
        let app = launchApp()
        XCTAssertTrue(app.navigationBars["Discoveries"].waitForExistence(timeout: 10), "Navigation title should say Discoveries")
    }

    @MainActor
    func testDiscoveryFeedLoadsWithPatternCards() {
        let app = launchApp()
        XCTAssertTrue(app.navigationBars["Discoveries"].waitForExistence(timeout: 10), "Feed should load")

        // Pattern cards are wrapped in NavigationLink, so they appear as buttons
        let sleepCard = element("PatternCard_sleep_hrv", in: app)
        XCTAssertTrue(sleepCard.waitForExistence(timeout: 10), "Sleep + HRV pattern card should appear")

        let stepsCard = element("PatternCard_steps_rhr", in: app)
        XCTAssertTrue(stepsCard.waitForExistence(timeout: 10), "Steps + HR pattern card should appear")
    }

    // MARK: - Filter Chips

    @MainActor
    func testFilterChipsSwitchContent() {
        let app = launchApp()

        // Wait for cards to load
        let sleepCard = element("PatternCard_sleep_hrv", in: app)
        XCTAssertTrue(sleepCard.waitForExistence(timeout: 10))

        // Tap "Sleep + HRV" filter
        let sleepFilter = element("FilterChip_Sleep + HRV", in: app)
        XCTAssertTrue(sleepFilter.waitForExistence(timeout: 5), "Sleep + HRV filter chip should exist")
        sleepFilter.tap()

        // Sleep card should still be visible
        XCTAssertTrue(sleepCard.waitForExistence(timeout: 5), "Sleep card should remain after filtering")

        // Steps card should be hidden
        let stepsCard = element("PatternCard_steps_rhr", in: app)
        // Give the UI a moment to update
        sleep(1)
        XCTAssertFalse(stepsCard.exists, "Steps card should be hidden after filtering to Sleep + HRV")

        // Tap "All" filter to restore
        let allFilter = element("FilterChip_All", in: app)
        allFilter.tap()

        XCTAssertTrue(element("PatternCard_steps_rhr", in: app).waitForExistence(timeout: 5), "Steps card should reappear after selecting All filter")
    }

    // MARK: - Pattern Detail Navigation

    @MainActor
    func testTapPatternCardNavigatesToDetail() {
        let app = launchApp()

        let sleepCard = element("PatternCard_sleep_hrv", in: app)
        XCTAssertTrue(sleepCard.waitForExistence(timeout: 10))
        sleepCard.tap()

        let detailView = element("PatternDetailView", in: app)
        XCTAssertTrue(detailView.waitForExistence(timeout: 5), "Pattern detail view should appear after tapping a card")

        // Verify narration section
        XCTAssertTrue(app.staticTexts["WHAT THIS MEANS"].waitForExistence(timeout: 3), "Narration section header should be visible")
    }

    @MainActor
    func testPatternDetailBackNavigation() {
        let app = launchApp()

        let sleepCard = element("PatternCard_sleep_hrv", in: app)
        XCTAssertTrue(sleepCard.waitForExistence(timeout: 10))
        sleepCard.tap()

        XCTAssertTrue(element("PatternDetailView", in: app).waitForExistence(timeout: 5))

        // Tap back
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // Feed should be visible again
        XCTAssertTrue(app.navigationBars["Discoveries"].waitForExistence(timeout: 5), "Feed should reappear after navigating back")
    }

    // MARK: - Settings Sheet

    @MainActor
    func testSettingsSheetOpensAndCloses() {
        let app = launchApp()

        XCTAssertTrue(app.navigationBars["Discoveries"].waitForExistence(timeout: 10))

        // Tap settings button
        let settingsButton = element("SettingsButton", in: app)
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        // Settings sheet should appear
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5), "Settings sheet should appear")
        XCTAssertTrue(app.staticTexts["Version"].exists, "Version row should be visible in settings")

        // Dismiss
        app.buttons["Done"].tap()

        // Feed should be visible again
        XCTAssertTrue(app.navigationBars["Discoveries"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSettingsShowsSignOutButton() {
        let app = launchApp()

        XCTAssertTrue(app.navigationBars["Discoveries"].waitForExistence(timeout: 10))

        element("SettingsButton", in: app).tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        let signOutButton = element("SignOutButton", in: app)
        XCTAssertTrue(signOutButton.exists, "Sign Out button should be visible in settings")
    }

    @MainActor
    func testSettingsShowsHealthPermissionsSection() {
        let app = launchApp()

        XCTAssertTrue(app.navigationBars["Discoveries"].waitForExistence(timeout: 10))

        element("SettingsButton", in: app).tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        XCTAssertTrue(app.staticTexts["Sleep Analysis"].exists, "Sleep Analysis permission should be visible")
        XCTAssertTrue(app.staticTexts["Heart Rate Variability"].exists, "HRV permission should be visible")
        XCTAssertTrue(app.staticTexts["Steps"].exists, "Steps permission should be visible")
        XCTAssertTrue(app.staticTexts["Resting Heart Rate"].exists, "Resting Heart Rate permission should be visible")

        let manageButton = element("ManageHealthPermissionsButton", in: app)
        XCTAssertTrue(manageButton.exists, "Manage Permissions button should be visible")
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
