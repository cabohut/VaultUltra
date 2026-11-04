//
//  RestoreSuggestedItemsTests.swift
//  VaultUltraTests
//
//  Created by bugs on 11/4/26.
//      11-04-2026 - tests restoreSuggestedItems against an in-memory store
//

import XCTest
import CoreData
@testable import VaultUltra

final class RestoreSuggestedItemsTests: XCTestCase {

    private var persistence: PersistenceController!
    private var context: NSManagedObjectContext { persistence.container.viewContext }

    private var totalSuggestions: Int {
        SmartFolderTemplates.all.reduce(0) { $0 + $1.suggestedItems.count }
    }

    override func setUp() {
        super.setUp()
        persistence = PersistenceController(inMemory: true)
    }

    override func tearDown() {
        persistence = nil
        super.tearDown()
    }

    private func fetchFolders(named name: String? = nil) throws -> [Folder] {
        let request: NSFetchRequest<Folder> = Folder.fetchRequest()
        if let name {
            request.predicate = NSPredicate(format: "name == %@", name)
        }
        return try context.fetch(request)
    }

    private func pending(_ folder: Folder) -> [String] {
        folder.pendingSuggestions?.split(separator: ",").map(String.init) ?? []
    }

    func testFreshStoreCreatesAllSmartFoldersAndSuggestions() throws {
        let result = persistence.restoreSuggestedItems()

        XCTAssertEqual(result.folders, SmartFolderTemplates.all.count)
        XCTAssertEqual(result.suggestions, totalSuggestions)

        let folders = try fetchFolders()
        XCTAssertEqual(folders.count, SmartFolderTemplates.all.count)
        XCTAssertTrue(folders.allSatisfy { $0.isSmartFolder })

        for template in SmartFolderTemplates.all {
            let folder = try XCTUnwrap(folders.first { $0.name == template.name })
            XCTAssertEqual(pending(folder), template.suggestedItems)
            XCTAssertEqual(folder.icon, template.icon)
        }
    }

    func testRunningTwiceChangesNothingTheSecondTime() {
        _ = persistence.restoreSuggestedItems()
        let second = persistence.restoreSuggestedItems()

        XCTAssertEqual(second.folders, 0)
        XCTAssertEqual(second.suggestions, 0)
    }

    func testSkippedSuggestionIsRestored() throws {
        _ = persistence.restoreSuggestedItems()

        let legal = try XCTUnwrap(try fetchFolders(named: "Legal").first)
        legal.pendingSuggestions = "Will"
        try context.save()

        let result = persistence.restoreSuggestedItems()

        XCTAssertEqual(result.folders, 0)
        XCTAssertEqual(result.suggestions, 3)
        XCTAssertEqual(pending(legal), SmartFolderTemplates.template(forFolderName: "Legal")?.suggestedItems)
    }

    func testTypesThatAlreadyHaveAnItemAreNotSuggested() throws {
        let legal = Folder(context: context)
        legal.name = "Legal"
        legal.icon = "doc.text"
        legal.isSmartFolder = true
        legal.sortOrder = 0
        legal.createdDate = Date()

        let item = Item(context: context)
        item.title = "My Will"
        item.itemType = "Will"
        item.createdDate = Date()
        item.modifiedDate = Date()
        item.addToFolders(legal)
        try context.save()

        _ = persistence.restoreSuggestedItems()

        XCTAssertFalse(pending(legal).contains("Will"))
        XCTAssertEqual(pending(legal).count, 3)
    }

    func testFolderWithAllTypesPresentGetsNilSuggestions() throws {
        let legal = Folder(context: context)
        legal.name = "Legal"
        legal.isSmartFolder = true
        legal.sortOrder = 0
        legal.createdDate = Date()

        for type in SmartFolderTemplates.template(forFolderName: "Legal")?.suggestedItems ?? [] {
            let item = Item(context: context)
            item.itemType = type
            item.createdDate = Date()
            item.modifiedDate = Date()
            item.addToFolders(legal)
        }
        try context.save()

        _ = persistence.restoreSuggestedItems()

        XCTAssertNil(legal.pendingSuggestions)
    }

    func testDeletedSmartFolderIsRecreated() throws {
        _ = persistence.restoreSuggestedItems()

        let legal = try XCTUnwrap(try fetchFolders(named: "Legal").first)
        context.delete(legal)
        try context.save()

        let result = persistence.restoreSuggestedItems()

        XCTAssertEqual(result.folders, 1)
        XCTAssertEqual(result.suggestions, 4)
        XCTAssertEqual(try fetchFolders(named: "Legal").count, 1)
    }

    func testCustomFolderWithSameNameIsLeftAlone() throws {
        let custom = Folder(context: context)
        custom.name = "Legal"
        custom.isSmartFolder = false
        custom.sortOrder = 0
        custom.createdDate = Date()
        try context.save()

        let result = persistence.restoreSuggestedItems()

        XCTAssertEqual(result.folders, SmartFolderTemplates.all.count - 1)
        XCTAssertNil(custom.pendingSuggestions)
        XCTAssertEqual(try fetchFolders(named: "Legal").count, 1)
    }

    func testNewFoldersGetSortOrdersAfterExistingOnes() throws {
        let custom = Folder(context: context)
        custom.name = "My Stuff"
        custom.isSmartFolder = false
        custom.sortOrder = 7
        custom.createdDate = Date()
        try context.save()

        _ = persistence.restoreSuggestedItems()

        let created = try fetchFolders().filter { $0.isSmartFolder }
        XCTAssertTrue(created.allSatisfy { $0.sortOrder > 7 })
        XCTAssertEqual(Set(created.map(\.sortOrder)).count, created.count)
    }
}
