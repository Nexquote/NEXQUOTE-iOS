import XCTest

final class AppHarnessUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testColdLaunchRouteDelivery() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-NQHarnessRoute",
            "/app/rates/import?source=deep-link",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Rate import"].waitForExistence(timeout: 10))
    }

    func testSanitizedShareHandoff() {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "NQ_HARNESS_SHARE_TEXT": "Synthetic freight request for simulator proof",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Quote intake"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Shared content ready"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Synthetic freight request for simulator proof"].exists)
    }

    func testHarnessQuickActionRoundTrip() {
        let app = XCUIApplication()
        app.launch()
        let action = app.buttons["Simulate Quick Action"]
        XCTAssertTrue(action.waitForExistence(timeout: 10))
        action.tap()
        XCTAssertTrue(app.staticTexts["Quote intake"].waitForExistence(timeout: 5))
    }

    func testOfflineStateDoesNotClaimSuccess() {
        let app = XCUIApplication()
        app.launch()
        let action = app.buttons["Show offline state"]
        XCTAssertTrue(action.waitForExistence(timeout: 10))
        action.tap()
        XCTAssertTrue(app.staticTexts["Offline — no action has been confirmed"].waitForExistence(timeout: 5))
    }
}
