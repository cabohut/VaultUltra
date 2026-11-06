//
//  VaultUltraUITests.swift
//  VaultUltraUITests
//      11-04-2026 - UI flows: folders, items, empty-item cleanup, search
//      11-05-2026 - added Documents tab tests
//

import XCTest

final class VaultUltraUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    // MARK: - Helpers

    private func createFolder(named name: String) {
        app.navigationBars.buttons["New Folder"].tap()
        let alert = app.alerts["New Folder"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        let field = alert.textFields["Folder name"]
        field.tap()
        field.typeText(name)
        alert.buttons["Create"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
    }

    private func openFolder(named name: String) {
        app.staticTexts[name].tap()
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 5))
    }

    /// From inside a folder: New Item > Blank Item, landing on the item screen.
    private func createBlankItem() {
        app.navigationBars.buttons["New Item"].tap()
        let blank = app.buttons["Blank Item"]
        XCTAssertTrue(blank.waitForExistence(timeout: 5))
        blank.tap()
        XCTAssertTrue(app.textFields["Title"].waitForExistence(timeout: 5))
    }

    private func tapDone() {
        app.navigationBars.buttons["Done"].tap()
    }

    /// Creates a folder, adds a blank item with the given title, and returns to the folder screen.
    private func createFolderWithTitledItem(folder: String, title: String) {
        createFolder(named: folder)
        openFolder(named: folder)
        createBlankItem()
        let field = app.textFields["Title"]
        field.tap()
        field.typeText(title)
        tapDone()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
    }

    // MARK: - Tests

    func testLaunchSkipsLockAndShowsSeededFolders() {
        XCTAssertTrue(app.tabBars.buttons["Folders"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Documents"].exists)
        XCTAssertTrue(app.tabBars.buttons["Search"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
        XCTAssertTrue(app.staticTexts["Legal"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Financial"].exists)
    }

    func testCreateFolderAppearsInList() {
        createFolder(named: "Test Folder")
    }

    func testNewCustomFolderStartsEmpty() {
        createFolder(named: "Test Folder")
        openFolder(named: "Test Folder")
        XCTAssertTrue(app.staticTexts["No Items Yet"].waitForExistence(timeout: 5))
    }

    func testEmptyBlankItemIsDeletedOnDone() {
        createFolder(named: "Test Folder")
        openFolder(named: "Test Folder")

        createBlankItem()
        tapDone()

        // Cleanup runs about half a second after the screen slides away
        XCTAssertTrue(app.staticTexts["No Items Yet"].waitForExistence(timeout: 5))
    }

    func testItemWithATitleIsKept() {
        createFolder(named: "Test Folder")
        openFolder(named: "Test Folder")

        createBlankItem()
        let title = app.textFields["Title"]
        title.tap()
        title.typeText("Keep Me")
        tapDone()

        XCTAssertTrue(app.staticTexts["Keep Me"].waitForExistence(timeout: 5))
        // Give the delayed cleanup time to run, then confirm the item survived
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertTrue(app.staticTexts["Keep Me"].exists)
        XCTAssertFalse(app.staticTexts["No Items Yet"].exists)
    }

    func testEmptySuggestedItemIsDeletedAndSuggestionReturns() {
        openFolder(named: "Legal")

        let suggestion = app.buttons["Will"]
        XCTAssertTrue(suggestion.waitForExistence(timeout: 5))
        suggestion.tap()
        XCTAssertTrue(app.textFields["Title"].waitForExistence(timeout: 5))
        tapDone()

        Thread.sleep(forTimeInterval: 1.5)

        // Back to the folder list: all four suggestions should be pending again
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["4 suggested items remaining"].waitForExistence(timeout: 5))
    }

    func testSearchFindsItemByTitle() {
        createFolderWithTitledItem(folder: "Test Folder", title: "Passport Copy")

        app.tabBars.buttons["Search"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("passport")

        XCTAssertTrue(app.staticTexts["Passport Copy"].waitForExistence(timeout: 5))
    }

    func testSearchWithNoMatchShowsNoResults() {
        createFolderWithTitledItem(folder: "Test Folder", title: "Passport Copy")

        app.tabBars.buttons["Search"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("zzzz")

        XCTAssertTrue(app.staticTexts["Passport Copy"].waitForNonExistence(timeout: 5))
    }

    func testDocumentsTabStartsEmpty() {
        app.tabBars.buttons["Documents"].tap()
        XCTAssertTrue(app.staticTexts["No Documents Yet"].waitForExistence(timeout: 5))
    }

    func testItemAppearsInDocumentsTab() {
        createFolderWithTitledItem(folder: "Test Folder", title: "Listed Doc")

        app.tabBars.buttons["Documents"].tap()
        XCTAssertTrue(app.staticTexts["Listed Doc"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["No Documents Yet"].exists)
    }
}
