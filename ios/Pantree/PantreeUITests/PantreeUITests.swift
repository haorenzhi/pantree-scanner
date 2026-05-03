import XCTest

final class PantreeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchesWithDashboardAndInventory() throws {
        let app = launchApp()
        XCTAssertTrue(app.otherElements["PantreeRoot"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Local-only food intelligence"].exists)

        app.tabBars.buttons["Inventory"].tap()
    XCTAssertTrue(app.staticTexts["Spinach"].waitForExistence(timeout: 5))
    }

    func testReceiptImportFlow() throws {
        let app = launchApp()
        app.tabBars.buttons["Receipt"].tap()
        XCTAssertTrue(app.navigationBars["Receipt"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Choose Receipt Photo"].exists)

        app.buttons["Use Sample Receipt"].tap()
        app.buttons["Import Receipt"].tap()

        XCTAssertTrue(app.staticTexts["Parsed locally"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Eggs"].exists)
        XCTAssertTrue(app.staticTexts["Milk"].exists)
    }

    func testPhotoPredictionSampleFlow() throws {
        let app = launchApp()
        app.tabBars.buttons["Photo"].tap()
        XCTAssertTrue(app.navigationBars["Photo"].waitForExistence(timeout: 3))

        app.buttons["Use Sample Meal Photo"].tap()

        XCTAssertTrue(app.staticTexts["Predictions"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Spinach"].exists)
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode"]
        app.launch()
        return app
    }
}
