//
//  ItemCleanupTests.swift
//  VaultUltraTests
//
//      11-04-2026 - tests empty-item detection and suggestion restore ordering
//

import XCTest
import CoreData
@testable import VaultUltra

final class ItemCleanupTests: XCTestCase {

    private var persistence: PersistenceController!
    private var context: NSManagedObjectContext { persistence.container.viewContext }

    override func setUp() {
        super.setUp()
        persistence = PersistenceController(inMemory: true)
    }

    override func tearDown() {
        persistence = nil
        super.tearDown()
    }

    private func makeItem() -> Item {
        let item = Item(context: context)
        item.title = ""
        item.createdDate = Date()
        item.modifiedDate = Date()
        return item
    }

    private func addField(to item: Item, value: String) {
        let field = CustomField(context: context)
        field.key = "Key"
        field.fieldType = CustomFieldType.text.rawValue
        field.stringValue = value
        field.item = item
    }

    // MARK: - hasNoContent

    func testBrandNewItemHasNoContent() {
        XCTAssertTrue(ItemCleanup.hasNoContent(makeItem()))
    }

    func testItemWithOnlyEmptyTemplateFieldsHasNoContent() {
        let item = makeItem()
        addField(to: item, value: "")
        addField(to: item, value: "   ")
        XCTAssertTrue(ItemCleanup.hasNoContent(item))
    }

    func testTitleCountsAsContent() {
        let item = makeItem()
        item.title = "Mom's Will"
        XCTAssertFalse(ItemCleanup.hasNoContent(item))
    }

    func testWhitespaceTitleDoesNotCountAsContent() {
        let item = makeItem()
        item.title = "   "
        XCTAssertTrue(ItemCleanup.hasNoContent(item))
    }

    func testNotesCountAsContent() {
        let item = makeItem()
        item.notes = "Remember this"
        XCTAssertFalse(ItemCleanup.hasNoContent(item))
    }

    func testFilledFieldCountsAsContent() {
        let item = makeItem()
        addField(to: item, value: "")
        addField(to: item, value: "12345")
        XCTAssertFalse(ItemCleanup.hasNoContent(item))
    }

    func testAttachmentCountsAsContent() {
        let item = makeItem()
        let attachment = Attachment(context: context)
        attachment.fileName = "scan.jpg"
        attachment.item = item
        XCTAssertFalse(ItemCleanup.hasNoContent(item))
    }

    // MARK: - restoredSuggestions

    func testRestoredSuggestionGoesBackInTemplateOrder() {
        let result = ItemCleanup.restoredSuggestions(
            "Will",
            current: ["Trust Documents", "Healthcare Directive"],
            folderName: "Legal"
        )
        XCTAssertEqual(result, ["Will", "Trust Documents", "Healthcare Directive"])
    }

    func testRestoredSuggestionInTheMiddle() {
        let result = ItemCleanup.restoredSuggestions(
            "Power of Attorney",
            current: ["Will", "Healthcare Directive"],
            folderName: "Legal"
        )
        XCTAssertEqual(result, ["Will", "Power of Attorney", "Healthcare Directive"])
    }

    func testRestoringExistingSuggestionChangesNothing() {
        let current = ["Will", "Passport"]
        let result = ItemCleanup.restoredSuggestions("Will", current: current, folderName: "Legal")
        XCTAssertEqual(result, current)
    }

    func testRestoringIntoEmptyList() {
        let result = ItemCleanup.restoredSuggestions("Will", current: [], folderName: "Legal")
        XCTAssertEqual(result, ["Will"])
    }

    func testRestoringIntoUnknownFolderAppendsWithoutCrashing() {
        let result = ItemCleanup.restoredSuggestions("Will", current: ["Passport"], folderName: "My Custom Folder")
        XCTAssertEqual(Set(result), ["Will", "Passport"])
        XCTAssertEqual(result.count, 2)
    }
    
    func testNewlinesOnlyNotesCountAsEmpty() {
        let item = Item(context: context)
        item.title = ""
        item.notes = "\n \n"
        XCTAssertTrue(ItemCleanup.hasNoContent(item))
    }
}
