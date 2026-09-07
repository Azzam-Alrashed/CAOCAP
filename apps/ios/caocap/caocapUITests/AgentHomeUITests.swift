import XCTest

final class AgentHomeUITests: XCTestCase {
    @MainActor
    func testHomeWorkspaceAndEmptyLibraryJourneys() {
        continueAfterFailure = false
        let app = XCUIApplication()
        // Override initial library lookup without erasing the simulator's other preferences.
        let baseArguments = ["-intro_completed_v1", "YES", "-personalization_survey_completed_v1", "YES"]
        app.launchArguments = baseArguments + ["-agent_library_v1", "fresh-ui-test"]
        app.launch()
        let captain = app.buttons["agent.open.cocaptain"]
        XCTAssertTrue(captain.waitForExistence(timeout: 20))
        XCTAssertTrue(app.tabBars.firstMatch.exists)
        XCTAssertTrue(app.buttons["Home"].isSelected)
        XCTAssertTrue(app.buttons["agent.open.costar"].exists)
        XCTAssertFalse(app.buttons["workspace.chat"].exists)
        capture("Home", app: app)

        app.buttons["Explore"].tap()
        XCTAssertTrue(app.staticTexts["Discover your next agent"].waitForExistence(timeout: 5))
        app.buttons["Communities"].tap()
        XCTAssertTrue(app.staticTexts["Build together"].waitForExistence(timeout: 5))
        app.buttons["Home"].tap()
        app.buttons["home.create"].tap()
        XCTAssertTrue(app.staticTexts["Agent setup is coming soon"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(captain.waitForExistence(timeout: 5))

        app.buttons["home.profile"].tap()
        let settings = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Settings'")).firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
        // Relaunch to dismiss the existing settings sheet without depending on its layout.
        app.terminate()
        app.launch()
        XCTAssertTrue(captain.waitForExistence(timeout: 15))

        captain.tap()
        XCTAssertTrue(app.buttons["workspace.back"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Home"].exists)
        XCTAssertTrue(app.buttons["workspace.chat"].waitForExistence(timeout: 5))
        capture("CoCaptain Workspace", app: app)
        app.buttons["workspace.chat"].tap()
        let composer = app.textFields.firstMatch
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        composer.tap()
        composer.typeText("Captain draft stays here")
        app.buttons["Done"].tap()
        app.buttons["workspace.back"].tap()
        XCTAssertTrue(captain.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["workspace.chat"].exists)

        app.buttons["agent.open.costar"].tap()
        app.buttons["workspace.chat"].tap()
        XCTAssertTrue(app.staticTexts["CoStar"].waitForExistence(timeout: 5))
        XCTAssertNotEqual(app.textFields.firstMatch.value as? String, "Captain draft stays here")
        app.buttons["Done"].tap()
        app.buttons["workspace.back"].tap()
        captain.tap()
        app.buttons["workspace.chat"].tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields.firstMatch.value as? String, "Captain draft stays here")
        capture("Agent chat draft", app: app)
        app.buttons["Done"].tap()
        app.buttons["workspace.back"].tap()

        for id in ["cocaptain", "costar"] {
            app.buttons["agent.options.\(id)"].tap()
            app.buttons["Remove from Home"].tap()
        }
        XCTAssertTrue(app.staticTexts["Your agents start here"].exists)
        capture("Empty Home", app: app)
        app.buttons["home.explore"].tap()
        XCTAssertTrue(app.staticTexts["Discover your next agent"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = baseArguments
        app.launch()
        XCTAssertTrue(app.staticTexts["Your agents start here"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["home.create"].exists)
        XCTAssertTrue(app.buttons["home.explore"].exists)
    }

    @MainActor
    func testHomeWithLargeText() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "-intro_completed_v1", "YES", "-personalization_survey_completed_v1", "YES",
            "-agent_library_v1", "fresh-ui-test",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()
        XCTAssertTrue(app.buttons["home.create"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["home.create"].isHittable)
        XCTAssertGreaterThan(app.windows.firstMatch.frame.width, 0)
        for title in ["Explore", "Home", "Communities"] {
            let tab = app.buttons[title]
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: tab)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 15), .completed)
            XCTAssertGreaterThan(tab.frame.minY, app.windows.firstMatch.frame.height / 2)
        }
        app.buttons["Explore"].tap()
        XCTAssertTrue(app.staticTexts["Discover your next agent"].waitForExistence(timeout: 5))
        app.buttons["Communities"].tap()
        XCTAssertTrue(app.staticTexts["Build together"].waitForExistence(timeout: 5))
        app.buttons["Home"].tap()
        capture("Home with accessibility text", app: app)
        defer { XCUIDevice.shared.orientation = .portrait }
        if app.windows.firstMatch.frame.width >= 600 {
            XCUIDevice.shared.orientation = .landscapeLeft
            let landscape = XCTNSPredicateExpectation(
                predicate: NSPredicate { _, _ in app.windows.firstMatch.frame.width > app.windows.firstMatch.frame.height }, object: app
            )
            XCTAssertEqual(XCTWaiter.wait(for: [landscape], timeout: 10), .completed)
            for title in ["Explore", "Home", "Communities"] {
                let tab = app.buttons[title]
                XCTAssertTrue(tab.isHittable)
                XCTAssertGreaterThan(tab.frame.minY, app.windows.firstMatch.frame.height / 2)
            }
            app.buttons["Explore"].tap()
            XCTAssertTrue(app.staticTexts["Discover your next agent"].waitForExistence(timeout: 5))
            app.buttons["Home"].tap()
            capture("iPad landscape bottom tabs", app: app)
        }
        let captain = app.buttons["agent.open.cocaptain"]
        let visibleBottom = app.buttons["Home"].frame.minY
        for _ in 0..<3 where captain.frame.maxY > visibleBottom {
            app.swipeUp()
        }
        captain.tap()
        XCTAssertTrue(app.buttons["workspace.back"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["workspace.back"].isHittable)
        XCTAssertFalse(app.buttons["Home"].exists)
        capture("Workspace with accessibility text", app: app)
        app.buttons["workspace.back"].tap()
        app.buttons["home.create"].tap()
        XCTAssertTrue(app.staticTexts["Agent setup is coming soon"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
    }

    @MainActor
    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
