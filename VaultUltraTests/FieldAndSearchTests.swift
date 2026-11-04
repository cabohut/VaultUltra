//
//  FieldAndSearchTests.swift
//  VaultUltraTests
//
//  Created by bugs on 11/4/26.
//      11-04-2026 - tests displayValue, date storage format, and search
//

import XCTest
import CoreData
@testable import VaultUltra

final class FieldAndSearchTests: XCTestCase {

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

    @discardableResult
    private func makeItem(title: String = "", notes: String? = nil) -> Item {
        let item = Item(context: context)
        item.title = title
        item.notes = notes
        item.createdDate = Date()
        item.modifiedDate = Date()
        return item
    }

    private func addField(to item: Item, key: String = "Key", value: String, sensitive: Bool = false) {
        let field = CustomField(context: context)
        field.key = key
        field.fieldType = CustomFieldType.text.rawValue
        field.isSensitive = sensitive
        field.stringValue = value
        field.item = item
    }

    private func titles(for text: String) -> [String] {
        ItemSearch.results(for: text, in: context).map { $0.title ?? "" }
    }

    // MARK: - displayValue

    func testDisplayValueDefaultsToEmptyString() {
        let field = CustomField(context: context)
        XCTAssertNil(field.stringValue)
        XCTAssertEqual(field.displayValue, "")
    }

    func testDisplayValueSetWritesStringValue() {
        let field = CustomField(context: context)
        field.displayValue = "abc"
        XCTAssertEqual(field.stringValue, "abc")
        XCTAssertEqual(field.displayValue, "abc")
    }

    // MARK: - Date storage

    func testDateStorageUsesYearMonthDayFormat() {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 9
        components.hour = 12
        let date = Calendar.current.date(from: components)!

        XCTAssertEqual(CustomFieldRow.dateStorage.string(from: date), "2026-03-09")
    }

    func testDateStorageRoundTripKeepsTheSameDay() {
        let today = Date()
        let stored = CustomFieldRow.dateStorage.string(from: today)
        let parsed = CustomFieldRow.dateStorage.date(from: stored)

        XCTAssertNotNil(parsed)
        XCTAssertTrue(Calendar.current.isDate(parsed!, inSameDayAs: today))
    }

    func testFreeTextIsNotParsedAsADate() {
        XCTAssertNil(CustomFieldRow.dateStorage.date(from: "next Tuesday"))
        XCTAssertNil(CustomFieldRow.dateStorage.date(from: ""))
    }

    // MARK: - Search

    func testEmptySearchReturnsNothing() throws {
        makeItem(title: "Passport")
        try context.save()
        XCTAssertTrue(titles(for: "").isEmpty)
    }

    func testSearchMatchesTitleCaseInsensitively() throws {
        makeItem(title: "Mom's Will")
        makeItem(title: "Car Title")
        try context.save()
        XCTAssertEqual(titles(for: "will"), ["Mom's Will"])
    }

    func testSearchMatchesNotes() throws {
        makeItem(title: "A", notes: "Stored in the fireproof safe")
        makeItem(title: "B", notes: "Nothing here")
        try context.save()
        XCTAssertEqual(titles(for: "fireproof"), ["A"])
    }

    func testSearchMatchesAttachmentOCRText() throws {
        let item = makeItem(title: "Scanned Doc")
        let attachment = Attachment(context: context)
        attachment.fileName = "scan.jpg"
        attachment.ocrText = "POLICY NUMBER 998877"
        attachment.item = item
        makeItem(title: "Other")
        try context.save()
        XCTAssertEqual(titles(for: "998877"), ["Scanned Doc"])
    }

    func testSearchMatchesNonSensitiveFieldValues() throws {
        let item = makeItem(title: "Bank")
        addField(to: item, key: "Bank Name", value: "First Credit Union")
        try context.save()
        XCTAssertEqual(titles(for: "credit union"), ["Bank"])
    }

    func testSearchDoesNotMatchSensitiveFieldValues() throws {
        let item = makeItem(title: "Bank")
        addField(to: item, key: "Account Number", value: "123456789", sensitive: true)
        try context.save()
        XCTAssertTrue(titles(for: "123456789").isEmpty)
    }

    func testSearchIgnoresDiacritics() throws {
        makeItem(title: "Café Receipt")
        try context.save()
        XCTAssertEqual(titles(for: "cafe"), ["Café Receipt"])
    }

    func testSearchWithNoMatchReturnsNothing() throws {
        makeItem(title: "Passport")
        try context.save()
        XCTAssertTrue(titles(for: "zzzz").isEmpty)
    }

    func testSearchResultsAreSortedByTitle() throws {
        makeItem(title: "Beta Policy")
        makeItem(title: "Alpha Policy")
        try context.save()
        XCTAssertEqual(titles(for: "policy"), ["Alpha Policy", "Beta Policy"])
    }
}
