//
//  FieldTemplateApplyTests.swift
//  VaultUltraTests
//      11-04-2026 - tests applyFields, assignStore, and CustomFieldType
//

import XCTest
import CoreData
@testable import VaultUltra

final class FieldTemplateApplyTests: XCTestCase {

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

    /// assignStore only works for a saved parent, so the folder is saved first.
    private func makeSavedFolder() throws -> Folder {
        let folder = Folder(context: context)
        folder.name = "Test"
        folder.sortOrder = 0
        folder.createdDate = Date()
        try context.save()
        return folder
    }

    private func makeItem(type: String?, in folder: Folder) -> Item {
        let item = Item(context: context)
        item.title = ""
        item.itemType = type
        item.createdDate = Date()
        item.modifiedDate = Date()
        item.addToFolders(folder)
        return item
    }

    private func fields(of item: Item) -> [CustomField] {
        ((item.customFields as? Set<CustomField>) ?? []).sorted { ($0.key ?? "") < ($1.key ?? "") }
    }

    // MARK: - applyFields

    func testApplyFieldsCreatesOneFieldPerTemplateEntry() throws {
        let folder = try makeSavedFolder()
        let item = makeItem(type: "Passport", in: folder)

        ItemFieldTemplates.applyFields(for: "Passport", to: item, folder: folder, context: context)
        try context.save()

        let expected = try XCTUnwrap(ItemFieldTemplates.fields(for: "Passport"))
        let created = fields(of: item)
        XCTAssertEqual(created.count, expected.count)
        XCTAssertEqual(Set(created.compactMap(\.key)), Set(expected.map(\.key)))
    }

    func testApplyFieldsCopiesTypeAndSensitivityAndStartsEmpty() throws {
        let folder = try makeSavedFolder()
        let item = makeItem(type: "Passport", in: folder)

        ItemFieldTemplates.applyFields(for: "Passport", to: item, folder: folder, context: context)
        try context.save()

        let number = try XCTUnwrap(fields(of: item).first { $0.key == "Passport Number" })
        XCTAssertTrue(number.isSensitive)
        XCTAssertEqual(number.fieldType, CustomFieldType.text.rawValue)
        XCTAssertEqual(number.displayValue, "")

        let expiry = try XCTUnwrap(fields(of: item).first { $0.key == "Expiration Date" })
        XCTAssertFalse(expiry.isSensitive)
        XCTAssertEqual(expiry.fieldType, CustomFieldType.date.rawValue)
    }

    func testApplyFieldsLinksEachFieldToTheItem() throws {
        let folder = try makeSavedFolder()
        let item = makeItem(type: "Credit Card", in: folder)

        ItemFieldTemplates.applyFields(for: "Credit Card", to: item, folder: folder, context: context)
        try context.save()

        XCTAssertTrue(fields(of: item).allSatisfy { $0.item == item })
    }

    func testApplyFieldsForUnknownTypeCreatesNothing() throws {
        let folder = try makeSavedFolder()
        let item = makeItem(type: "Not A Type", in: folder)

        ItemFieldTemplates.applyFields(for: "Not A Type", to: item, folder: folder, context: context)
        try context.save()

        XCTAssertTrue(fields(of: item).isEmpty)
    }

    func testApplyFieldsWorksForEverySuggestedAndGenericType() throws {
        let folder = try makeSavedFolder()
        let types = SmartFolderTemplates.all.flatMap(\.suggestedItems) + ItemFieldTemplates.genericFallbackTypes

        for type in types {
            let item = makeItem(type: type, in: folder)
            ItemFieldTemplates.applyFields(for: type, to: item, folder: folder, context: context)
            XCTAssertEqual(
                fields(of: item).count,
                ItemFieldTemplates.fields(for: type)?.count,
                "\(type) created the wrong number of fields"
            )
        }
        XCTAssertNoThrow(try context.save())
    }

    // MARK: - assignStore

    func testAssignStorePutsNewObjectInTheParentsStore() throws {
        let folder = try makeSavedFolder()
        let parentStore = try XCTUnwrap(folder.objectID.persistentStore)

        let item = Item(context: context)
        item.title = "New"
        context.assignStore(of: folder, to: item)
        try context.save()

        XCTAssertTrue(item.objectID.persistentStore === parentStore)
    }

    func testAssignStoreWithUnsavedParentDoesNothingAndDoesNotCrash() throws {
        let unsavedFolder = Folder(context: context)
        unsavedFolder.name = "Unsaved"

        let item = Item(context: context)
        item.title = "New"
        context.assignStore(of: unsavedFolder, to: item)

        XCTAssertNoThrow(try context.save())
    }

    // MARK: - CustomFieldType

    func testFieldTypeDisplayNamesAndIDs() {
        XCTAssertEqual(CustomFieldType.text.displayName, "Text")
        XCTAssertEqual(CustomFieldType.date.displayName, "Date")
        XCTAssertEqual(CustomFieldType.currency.displayName, "Currency")
        XCTAssertEqual(CustomFieldType.number.displayName, "Number")
        XCTAssertEqual(CustomFieldType.currency.id, "currency")
        XCTAssertEqual(CustomFieldType.allCases.count, 4)
    }

    func testFieldTypeRawValuesRoundTrip() {
        for type in CustomFieldType.allCases {
            XCTAssertEqual(CustomFieldType(rawValue: type.rawValue), type)
        }
        XCTAssertNil(CustomFieldType(rawValue: "bogus"))
    }
}
