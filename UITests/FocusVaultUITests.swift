import XCTest

final class FocusVaultUITests: XCTestCase {
    func testFirstRunTimerAndVaultFlowFitsScreen() throws {
        let app = XCUIApplication()
        let passcode = "12345678"
        app.launch()

        let setupTitle = app.navigationBars["设置私人空间"]
        XCTAssertTrue(setupTitle.waitForExistence(timeout: 5))
        let portraitWindow = app.windows.firstMatch.frame
        XCTAssertGreaterThanOrEqual(portraitWindow.width, 375)
        XCTAssertGreaterThanOrEqual(portraitWindow.height, 667)
        assertContained(setupTitle, in: app)
        keepScreenshot("01-first-run-password")

        let password = app.secureTextFields["setup-passcode"]
        let confirmation = app.secureTextFields["setup-confirmation"]
        XCTAssertTrue(password.exists)
        XCTAssertTrue(confirmation.exists)
        password.tap()
        password.typeText(passcode)
        confirmation.tap()
        confirmation.typeText(passcode)
        app.buttons["setup-create"].tap()
        XCTAssertTrue(setupTitle.waitForNonExistence(timeout: 5))

        let timerTitle = app.navigationBars["计时器"]
        XCTAssertTrue(timerTitle.waitForExistence(timeout: 5))
        let duration = app.textFields["timer-duration"]
        XCTAssertTrue(duration.exists)
        assertContained(duration, in: app)
        duration.tap()
        XCTAssertTrue(app.keyboards.keys["1"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.keyboards.keys["Q"].exists)
        app.toolbars.buttons["完成"].tap()
        keepScreenshot("02-manual-timer-portrait")

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(timerTitle.waitForExistence(timeout: 3))
        XCTAssertTrue(duration.exists)
        app.swipeUp()
        XCTAssertTrue(app.buttons["timer-start"].exists)
        keepScreenshot("03-manual-timer-landscape")
        XCUIDevice.shared.orientation = .portrait
        app.swipeDown()

        replaceText(in: duration, with: "11111111")
        app.buttons["timer-start"].tap()
        XCTAssertTrue(app.staticTexts["计时中"].waitForExistence(timeout: 3))
        app.buttons["结束"].tap()

        let editableDuration = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == true"),
            object: duration
        )
        XCTAssertEqual(XCTWaiter.wait(for: [editableDuration], timeout: 3), .completed)

        replaceText(in: duration, with: passcode)
        app.buttons["timer-start"].tap()
        let vaultTitle = app.navigationBars["私人空间"]
        XCTAssertTrue(vaultTitle.waitForExistence(timeout: 5))
        assertContained(vaultTitle, in: app)
        keepScreenshot("04-private-vault-empty")
    }

    private func replaceText(in field: XCUIElement, with value: String) {
        field.tap()
        let rightEdge = field.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5))
        rightEdge.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 40))
        field.typeText(value)
        XCTAssertEqual(field.value as? String, value)
    }

    private func assertContained(_ element: XCUIElement, in app: XCUIApplication) {
        let window = app.windows.firstMatch.frame
        let frame = element.frame
        XCTAssertGreaterThanOrEqual(frame.minX, window.minX - 1)
        XCTAssertGreaterThanOrEqual(frame.minY, window.minY - 1)
        XCTAssertLessThanOrEqual(frame.maxX, window.maxX + 1)
        XCTAssertLessThanOrEqual(frame.maxY, window.maxY + 1)
    }

    private func keepScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
