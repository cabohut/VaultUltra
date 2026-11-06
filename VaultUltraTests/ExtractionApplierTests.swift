//
//  ExtractionApplierTests.swift
//  VaultUltraTests
//
//  Created by bugs on 11/5/26.
//      11-05-2026 - tests applying extracted fields to an item

import XCTest
import CoreData
@testable import VaultUltra

@MainActor
final class ExtractionApplierTests: XCTestCase {
    private var persistence: PersistenceController!
    private var context: NSManagedObjectContext!
    private var item: Item!

    override func setUp() {
        super.setUp()
        persistence = PersistenceController(inMemory: true)
        context = persistence.container.viewContext
        item = Item(context: context)
        item.title = "Test"
        item.createdDate = Date()
        item.modifiedDate = Date()
    }

    override func tearDown() {
        item = nil
        context = nil
        persistence = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func fields() -> [CustomField] {
        Array((item.customFields as? Set<CustomField>) ?? [])
    }

    private func field(named key: String) -> CustomField? {
        fields().first { $0.key == key }
    }

    private func addExistingField(key: String, value: String, isSensitive: Bool, type: CustomFieldType = .text) {
        let f = CustomField(context: context)
        f.key = key
        f.fieldType = type.rawValue
        f.isSensitive = isSensitive
        f.stringValue = value
        f.item = item
    }

    // MARK: - New fields

    func testNewKeyCreatesANonSensitiveTextField() {
        // "Provider" has no sensitive words, so it stays unmasked
        ExtractionApplier.apply([ExtractedField(key: "Provider", value: "Acme")], to: item, context: context)

        let created = field(named: "Provider")
        XCTAssertNotNil(created)
        XCTAssertEqual(created?.fieldType, CustomFieldType.text.rawValue)
        XCTAssertEqual(created?.isSensitive, false)
        XCTAssertEqual(created?.displayValue, "Acme")
    }

    func testNewKeyWithSensitiveNameIsMarkedSensitive() {
        ExtractionApplier.apply([ExtractedField(key: "Policy Number", value: "12345")], to: item, context: context)

        XCTAssertEqual(field(named: "Policy Number")?.isSensitive, true)
    }

    func testLooksSensitive() {
        XCTAssertTrue(ExtractionApplier.looksSensitive("Member ID"))
        XCTAssertTrue(ExtractionApplier.looksSensitive("Social Security Number"))
        XCTAssertTrue(ExtractionApplier.looksSensitive("Login Password"))
        XCTAssertFalse(ExtractionApplier.looksSensitive("Provider"))
        XCTAssertFalse(ExtractionApplier.looksSensitive("Phone Number"))
        XCTAssertFalse(ExtractionApplier.looksSensitive("Provider Name"))
    }

    // MARK: - Existing fields

    func testExistingKeyIsOverwrittenNotDuplicated() {
        addExistingField(key: "Provider", value: "Old", isSensitive: false)

        ExtractionApplier.apply([ExtractedField(key: "Provider", value: "New")], to: item, context: context)

        XCTAssertEqual(fields().count, 1)
        XCTAssertEqual(field(named: "Provider")?.displayValue, "New")
    }

    func testExistingFieldKeepsItsSensitivityAndType() {
        addExistingField(key: "Account Number", value: "", isSensitive: true, type: .number)

        ExtractionApplier.apply([ExtractedField(key: "Account Number", value: "999")], to: item, context: context)

        let existing = field(named: "Account Number")
        XCTAssertEqual(existing?.isSensitive, true)
        XCTAssertEqual(existing?.fieldType, CustomFieldType.number.rawValue)
        XCTAssertEqual(existing?.displayValue, "999")
    }

    func testMatchingIgnoresCaseAndSurroundingSpaces() {
        addExistingField(key: "Policy Number", value: "", isSensitive: true)

        ExtractionApplier.apply([ExtractedField(key: "  policy number ", value: "ABC")], to: item, context: context)

        XCTAssertEqual(fields().count, 1)
        XCTAssertEqual(field(named: "Policy Number")?.displayValue, "ABC")
    }

    // MARK: - Duplicates and repeats

    func testDuplicateKeysInOneApplyCreateOneFieldAndLastValueWins() {
        ExtractionApplier.apply(
            [ExtractedField(key: "Provider", value: "A"),
             ExtractedField(key: "provider", value: "B")],
            to: item,
            context: context
        )

        XCTAssertEqual(fields().count, 1)
        XCTAssertEqual(fields().first?.displayValue, "B")
    }

    func testApplyingTwiceDoesNotAddFields() {
        let suggestions = [
            ExtractedField(key: "Provider", value: "Acme"),
            ExtractedField(key: "Policy Number", value: "123")
        ]

        ExtractionApplier.apply(suggestions, to: item, context: context)
        ExtractionApplier.apply(suggestions, to: item, context: context)

        XCTAssertEqual(fields().count, 2)
    }

    func testBlankKeyIsSkipped() {
        ExtractionApplier.apply([ExtractedField(key: "   ", value: "x")], to: item, context: context)

        XCTAssertTrue(fields().isEmpty)
    }

    func testApplyUpdatesModifiedDate() {
        let old = Date(timeIntervalSince1970: 0)
        item.modifiedDate = old

        ExtractionApplier.apply([ExtractedField(key: "Provider", value: "Acme")], to: item, context: context)

        XCTAssertGreaterThan(item.modifiedDate ?? old, old)
    }
}
