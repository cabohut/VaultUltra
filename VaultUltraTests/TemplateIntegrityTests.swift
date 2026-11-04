//
//  TemplateIntegrityTests.swift
//  VaultUltraTests
//
//  Created by bugs on 11/4/26.
//      11-04-2026 - checks smart folder and item field templates stay consistent
//

import XCTest
@testable import VaultUltra

final class TemplateIntegrityTests: XCTestCase {

    private var allSuggestedTypes: [String] {
        SmartFolderTemplates.all.flatMap { $0.suggestedItems }
    }

    func testSmartFoldersHaveNamesIconsAndSuggestions() {
        for template in SmartFolderTemplates.all {
            XCTAssertFalse(template.name.isEmpty)
            XCTAssertFalse(template.icon.isEmpty, "\(template.name) has no icon")
            XCTAssertFalse(template.suggestedItems.isEmpty, "\(template.name) has no suggestions")
        }
    }

    func testSmartFolderNamesAreUnique() {
        let names = SmartFolderTemplates.all.map(\.name)
        XCTAssertEqual(names.count, Set(names).count)
    }

    func testSuggestedItemNamesAreUniqueAcrossFolders() {
        XCTAssertEqual(allSuggestedTypes.count, Set(allSuggestedTypes).count)
    }

    func testSuggestedItemsHaveNoCommas() {
        // pendingSuggestions is stored as a comma-separated string
        for type in allSuggestedTypes {
            XCTAssertFalse(type.contains(","), "\(type) would break pendingSuggestions")
        }
    }

    func testEverySuggestedItemHasFields() {
        for type in allSuggestedTypes {
            let fields = ItemFieldTemplates.fields(for: type)
            XCTAssertNotNil(fields, "\(type) has no field template")
            XCTAssertFalse(fields?.isEmpty ?? true, "\(type) has an empty field template")
        }
    }

    func testEverySuggestedItemHasItsOwnSymbol() {
        for type in allSuggestedTypes {
            XCTAssertNotEqual(ItemFieldTemplates.symbol(for: type), "doc", "\(type) falls back to the default symbol")
        }
    }

    func testGenericFallbackTypesHaveFieldsAndSymbols() {
        for type in ItemFieldTemplates.genericFallbackTypes {
            XCTAssertFalse(ItemFieldTemplates.fields(for: type)?.isEmpty ?? true, "\(type) has no fields")
            XCTAssertNotEqual(ItemFieldTemplates.symbol(for: type), "doc", "\(type) falls back to the default symbol")
        }
    }

    func testFieldKeysAreNonEmptyAndUniqueWithinEachType() {
        for type in allSuggestedTypes + ItemFieldTemplates.genericFallbackTypes {
            let keys = ItemFieldTemplates.fields(for: type)?.map(\.key) ?? []
            XCTAssertFalse(keys.contains(where: { $0.isEmpty }), "\(type) has an empty key")
            XCTAssertEqual(keys.count, Set(keys).count, "\(type) has duplicate keys")
        }
    }

    func testKeySensitiveFieldsAreMarkedSensitive() {
        let expected: [(type: String, key: String)] = [
            ("Social Security Card", "Social Security Number"),
            ("Passport", "Passport Number"),
            ("Driver's License", "License Number"),
            ("Bank Accounts", "Account Number"),
            ("Bank Accounts", "Login Password"),
            ("Credit Card", "Card Number"),
            ("Credit Card", "CVV"),
            ("Digital Accounts List", "Password")
        ]
        for (type, key) in expected {
            let field = ItemFieldTemplates.fields(for: type)?.first { $0.key == key }
            XCTAssertEqual(field?.isSensitive, true, "\(type) / \(key) should be sensitive")
        }
    }

    func testTemplateLookupByFolderName() {
        XCTAssertEqual(SmartFolderTemplates.template(forFolderName: "Legal")?.name, "Legal")
        XCTAssertNil(SmartFolderTemplates.template(forFolderName: "Not A Folder"))
    }

    func testUnknownTypeFallsBackSafely() {
        XCTAssertNil(ItemFieldTemplates.fields(for: "Not A Type"))
        XCTAssertEqual(ItemFieldTemplates.symbol(for: nil), "doc")
        XCTAssertEqual(ItemFieldTemplates.symbol(for: "Not A Type"), "doc")
    }
}
