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

    func testReceiptDetectSelectAndAddFlow() throws {
        let app = launchApp()
        app.tabBars.buttons["Receipt"].tap()
        XCTAssertTrue(app.navigationBars["Receipt"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Choose Receipt Photo"].exists)

        app.buttons["Use Sample Receipt"].tap()

        XCTAssertTrue(app.staticTexts["Parsed locally"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Eggs"].exists)
        XCTAssertTrue(app.staticTexts["Whole Milk"].exists)

        app.scrollViews.firstMatch.swipeUp()
        let bananas = app.staticTexts["Bananas"]
        XCTAssertTrue(bananas.waitForExistence(timeout: 5))
        bananas.tap()

        let addSelectedButton = app.buttons["AddSelectedReceiptItemsButton"]
        XCTAssertTrue(addSelectedButton.waitForExistence(timeout: 5))
        addSelectedButton.tap()

        XCTAssertTrue(app.staticTexts["Added 3 selected items to inventory."].waitForExistence(timeout: 5))
    }

    func testReceiptKeyboardCanBeDismissedBeforeSwitchingTabs() throws {
        let app = launchApp()
        app.tabBars.buttons["Receipt"].tap()
        XCTAssertTrue(app.navigationBars["Receipt"].waitForExistence(timeout: 3))

        let editor = app.textViews["ReceiptTextEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()

        let doneButton = app.buttons["DismissReceiptKeyboardButton"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        doneButton.tap()

        app.tabBars.buttons["Inventory"].tap()
        XCTAssertTrue(app.navigationBars["Inventory"].waitForExistence(timeout: 5))
    }

    func testPhotoPredictionSampleFlow() throws {
        let app = launchApp()
        app.tabBars.buttons["Diet"].tap()
        XCTAssertTrue(app.navigationBars["Diet"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Daily calories"].waitForExistence(timeout: 5))

        app.buttons["Use Sample Meal Photo"].tap()

        XCTAssertTrue(app.staticTexts["Meal predictions"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Spinach"].exists)
        let recordButton = app.buttons["Record Meal Calories"]
        if !recordButton.waitForExistence(timeout: 2) {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(recordButton.waitForExistence(timeout: 5))
        recordButton.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Recorded meal")).firstMatch.waitForExistence(timeout: 5))
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode"]
        app.launch()
        return app
    }
}
