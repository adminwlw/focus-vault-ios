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

        XCTAssertFalse(app.tabBars.buttons["记录"].exists)
        app.tabBars.buttons["秒表"].tap()
        let watch = app.buttons["stopwatch-start-pause"]
        XCTAssertTrue(watch.waitForExistence(timeout: 3))
        watch.tap()
        XCTAssertEqual(watch.label, "暂停")
        app.buttons["stopwatch-lap-reset"].tap()
        XCTAssertTrue(app.staticTexts["第 1 次"].exists)
        watch.tap()
        keepScreenshot("03-stopwatch-lap")
        app.buttons["stopwatch-lap-reset"].tap()
        XCTAssertFalse(app.staticTexts["第 1 次"].exists)
        app.tabBars.buttons["计时"].tap()

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

        app.buttons["vault-albums"].tap()
        app.buttons["albums-create"].tap()
        let albumName = app.alerts.textFields.firstMatch
        XCTAssertTrue(albumName.waitForExistence(timeout: 3))
        albumName.typeText("生活")
        app.alerts.buttons["保存"].tap()
        XCTAssertTrue(app.buttons["生活"].waitForExistence(timeout: 3))
        keepScreenshot("05-empty-album-created")
        app.buttons["生活"].tap()
        XCTAssertTrue(app.navigationBars["生活"].waitForExistence(timeout: 3))
        keepScreenshot("06-album-import-entry")
        let window = app.windows.firstMatch
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.65))
            .press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.65)))
        XCTAssertTrue(timerTitle.waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["生活"].exists)

        replaceText(in: duration, with: passcode)
        app.buttons["timer-start"].tap()
        XCTAssertTrue(vaultTitle.waitForExistence(timeout: 5))
        app.buttons["vault-albums"].tap()
        XCTAssertTrue(app.buttons["生活"].waitForExistence(timeout: 3))
        app.buttons["生活"].swipeLeft()
        app.buttons["重命名"].tap()
        let rename = app.alerts.textFields.firstMatch
        replaceText(in: rename, with: "旅行")
        app.alerts.buttons["保存"].tap()
        XCTAssertTrue(app.buttons["旅行"].waitForExistence(timeout: 3))
        app.buttons["旅行"].tap()
        app.buttons["vault-import"].tap()
        let pickerCancel = app.buttons["Cancel"].exists ? app.buttons["Cancel"] : app.buttons["取消"]
        XCTAssertTrue(pickerCancel.waitForExistence(timeout: 5))
        keepScreenshot("07-system-photo-picker")
        pickerCancel.tap()
        XCTAssertTrue(app.navigationBars["旅行"].waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(timerTitle.waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["旅行"].exists)
        keepScreenshot("08-background-locked")
        replaceText(in: duration, with: "1")
        app.buttons["timer-start"].tap()
        XCTAssertTrue(app.staticTexts["计时中"].waitForExistence(timeout: 3))
        replaceText(in: duration, with: passcode)
        app.buttons["timer-confirm-input"].tap()
        XCTAssertTrue(vaultTitle.waitForExistence(timeout: 5))
        app.buttons["vault-lock"].tap()
        XCTAssertTrue(app.staticTexts["计时中"].waitForExistence(timeout: 3))
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
