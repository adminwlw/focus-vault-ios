import XCTest

final class FocusVaultUITests: XCTestCase {
    func testFirstRunTimerAndVaultFlowFitsScreen() throws {
        let app = XCUIApplication()
        let passcode = "12345678"
        app.launchArguments = ["-ui-seed-media", "-ui-reset-state"]
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
        if app.otherElements["entry-practice-hint"].exists || app.buttons["暂不练习"].exists {
            replaceText(in: duration, with: passcode)
            app.buttons["timer-confirm-input"].tap()
            XCTAssertTrue(app.navigationBars["私人空间"].waitForExistence(timeout: 8))
            keepScreenshot("02-entry-practice-complete")
            app.buttons["vault-lock"].tap()
            XCTAssertTrue(timerTitle.waitForExistence(timeout: 5))
        }
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
        keepScreenshot("04-private-vault-media")
        app.buttons.matching(identifier: "vault-media-link").firstMatch.tap()
        XCTAssertTrue(app.buttons["下一项"].waitForExistence(timeout: 5))
        app.buttons["下一项"].tap()
        XCTAssertTrue(app.buttons["上一项"].isEnabled)
        XCTAssertTrue(app.staticTexts["gallery-position"].exists)
        keepScreenshot("05-photo-detail-next")
        app.navigationBars.buttons["私人空间"].tap()
        XCTAssertTrue(vaultTitle.waitForExistence(timeout: 5))

        app.buttons["vault-albums"].tap()
        app.buttons["albums-create"].tap()
        let albumName = app.alerts.textFields.firstMatch
        XCTAssertTrue(albumName.waitForExistence(timeout: 3))
        albumName.typeText("生活")
        app.alerts.buttons["保存"].tap()
        XCTAssertTrue(app.buttons["album-生活"].waitForExistence(timeout: 3))
        keepScreenshot("06-empty-album-created")
        app.buttons["album-生活"].tap()
        XCTAssertTrue(app.navigationBars["生活"].waitForExistence(timeout: 3))
        keepScreenshot("07-album-import-entry")
        let window = app.windows.firstMatch
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.65))
            .press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.65)))
        XCTAssertTrue(timerTitle.waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["生活"].exists)

        replaceText(in: duration, with: passcode)
        app.buttons["timer-start"].tap()
        XCTAssertTrue(vaultTitle.waitForExistence(timeout: 5))
        app.buttons["vault-albums"].tap()
        XCTAssertTrue(app.buttons["album-生活"].waitForExistence(timeout: 3))
        app.buttons["album-生活"].swipeLeft()
        app.buttons["重命名"].tap()
        let rename = app.alerts.textFields.firstMatch
        replaceText(in: rename, with: "旅行")
        app.alerts.buttons["保存"].tap()
        XCTAssertTrue(app.buttons["album-旅行"].waitForExistence(timeout: 3))
        app.buttons["album-旅行"].tap()
        app.buttons["vault-import"].tap()
        let pickerCancel = app.buttons["Cancel"].exists ? app.buttons["Cancel"] : app.buttons["取消"]
        XCTAssertTrue(pickerCancel.waitForExistence(timeout: 5))
        let pickerPhoto = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        XCTAssertTrue(pickerPhoto.waitForExistence(timeout: 20))
        keepScreenshot("08-system-photo-picker")
        pickerPhoto.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let addPhoto = app.navigationBars["Photos"].buttons["Done"]
        XCTAssertTrue(addPhoto.waitForExistence(timeout: 5))
        addPhoto.tap()
        XCTAssertTrue(app.navigationBars["旅行"].waitForExistence(timeout: 5))
        let keepOriginal = app.buttons["保留系统原件"]
        XCTAssertTrue(keepOriginal.waitForExistence(timeout: 10))
        if keepOriginal.exists {
            keepScreenshot("09-import-original-choice")
            keepOriginal.tap()
        }
        XCTAssertTrue(app.buttons.matching(identifier: "vault-media-link").firstMatch.waitForExistence(timeout: 5))
        keepScreenshot("10-imported-into-album")
        app.buttons["vault-more"].tap()
        app.buttons["vault-originals"].tap()
        XCTAssertTrue(app.navigationBars["系统原件"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["系统原件已保留（上次处理结果）"].exists)
        keepScreenshot("13-original-state-retained")
        app.navigationBars["系统原件"].buttons["完成"].tap()
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(timerTitle.waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["旅行"].exists)
        keepScreenshot("11-background-locked")
        replaceText(in: duration, with: "1")
        app.buttons["timer-start"].tap()
        XCTAssertTrue(app.staticTexts["计时中"].waitForExistence(timeout: 3))
        replaceText(in: duration, with: passcode)
        app.buttons["timer-confirm-input"].tap()
        XCTAssertTrue(vaultTitle.waitForExistence(timeout: 5))
        app.buttons["vault-lock"].tap()
        XCTAssertTrue(app.staticTexts["计时中"].waitForExistence(timeout: 3))
        app.buttons["结束"].tap()
        app.terminate()
        app.launchArguments.removeAll { $0 == "-ui-reset-state" }
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(timerTitle.waitForExistence(timeout: 5))
        app.swipeUp()
        XCTAssertTrue(app.buttons["timer-start"].exists)
        keepScreenshot("12-large-text-timer")
    }

    func testOrganizingVideoSearchTrashAndBatchExport() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-reset-state", "-ui-seed-media", "-ui-seed-video"]
        app.launch()
        XCTAssertTrue(app.secureTextFields["setup-passcode"].waitForExistence(timeout: 5))
        app.secureTextFields["setup-passcode"].tap()
        app.secureTextFields["setup-passcode"].typeText("12345678")
        app.secureTextFields["setup-confirmation"].tap()
        app.secureTextFields["setup-confirmation"].typeText("12345678")
        app.buttons["setup-create"].tap()
        XCTAssertTrue(app.buttons["暂不练习"].waitForExistence(timeout: 5))
        app.buttons["暂不练习"].tap()
        let duration = app.textFields["timer-duration"]
        replaceText(in: duration, with: "12345678")
        app.buttons["timer-confirm-input"].tap()
        let video = app.buttons.matching(identifier: "vault-media-link")
            .matching(NSPredicate(format: "label CONTAINS %@", "UI测试视频")).firstMatch
        XCTAssertTrue(video.waitForExistence(timeout: 15))
        video.tap()
        let mute = app.buttons["video-mute"]
        XCTAssertTrue(mute.waitForExistence(timeout: 10))
        XCTAssertEqual(mute.label, "开启声音")
        keepScreenshot("14-video-paused-muted")
        app.buttons["detail-more"].tap()
        app.buttons["名称与备注"].tap()
        let name = app.textFields["media-display-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap(); name.typeText("海边片段")
        let note = app.textViews["media-note"]
        note.tap(); note.typeText("周末散步")
        app.navigationBars["名称与备注"].buttons["保存"].tap()
        XCTAssertTrue(app.navigationBars["海边片段"].waitForExistence(timeout: 5))
        keepScreenshot("15-renamed-video")
        app.buttons["detail-lock"].tap()
        XCTAssertTrue(duration.waitForExistence(timeout: 5))
        replaceText(in: duration, with: "12345678")
        app.buttons["timer-confirm-input"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 8))
        search.tap(); search.typeText("周末\n")
        XCTAssertTrue(app.buttons.matching(identifier: "vault-media-link").firstMatch.waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons.matching(identifier: "vault-media-link").count, 1)
        keepScreenshot("16-search-note")
        replaceText(in: search, with: "没有这个项目")
        search.typeText("\n")
        XCTAssertTrue(app.staticTexts["没有符合条件的项目"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["vault-lock"].isHittable)
        keepScreenshot("17-filter-no-results")
        app.buttons["清除"].tap()
        if app.buttons["取消"].exists { app.buttons["取消"].tap() }
        app.scrollViews["vault-filter-bar"].swipeLeft()
        app.buttons["日期"].tap()
        app.buttons["选择日期…"].tap()
        XCTAssertTrue(app.navigationBars["按日期查找"].waitForExistence(timeout: 5))
        keepScreenshot("17-date-picker")
        app.buttons["查看当天"].tap()
        XCTAssertTrue(app.buttons["清除"].waitForExistence(timeout: 3))
        app.buttons["清除"].tap()
        let photo = app.buttons.matching(identifier: "vault-media-link")
            .matching(NSPredicate(format: "label CONTAINS %@", "UI测试照片2")).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 3))
        photo.tap()
        app.buttons["detail-more"].tap()
        app.buttons["移到最近删除"].tap()
        app.buttons["移到最近删除"].tap()
        XCTAssertTrue(app.buttons["vault-more"].waitForExistence(timeout: 5))
        app.buttons["vault-more"].tap()
        app.buttons["最近删除"].tap()
        XCTAssertTrue(app.staticTexts["剩余 30 天"].waitForExistence(timeout: 5))
        keepScreenshot("18-trash-thumbnail-days")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "预览 ")).firstMatch.tap()
        XCTAssertTrue(app.buttons["detail-more"].waitForExistence(timeout: 5))
        app.buttons["detail-more"].tap()
        app.buttons["恢复项目"].tap()
        XCTAssertTrue(app.navigationBars["最近删除"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["最近删除为空"].exists)
        keepScreenshot("19-trash-restored")
        app.navigationBars["最近删除"].buttons["完成"].tap()
        app.buttons["vault-more"].tap()
        app.buttons["管理私人空间"].tap()
        app.buttons["面容 ID / 触控 ID"].tap()
        XCTAssertTrue(app.switches["vault-biometric-toggle"].waitForExistence(timeout: 5))
        keepScreenshot("20-biometric-settings")
        app.buttons["modal-lock"].firstMatch.tap()
        XCTAssertTrue(duration.waitForExistence(timeout: 5))
        replaceText(in: duration, with: "12345678")
        app.buttons["timer-confirm-input"].tap()
        XCTAssertTrue(app.buttons["vault-select"].waitForExistence(timeout: 5))
        app.buttons["vault-select"].tap()
        app.buttons["全选"].tap()
        app.buttons["导出"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "导出 ")).firstMatch.tap()
        XCTAssertTrue(app.otherElements["vault-share-sheet"].waitForExistence(timeout: 10))
        keepScreenshot("21-batch-export-share")
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
