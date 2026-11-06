//
//  ServicesTests.swift
//  VaultUltraTests
//
//  Created by bugs on 11/4/26.
//      11-04-2026 - tests Keychain, GuideLoader parsing, and AppLockManager.lock()
//

import XCTest
@testable import VaultUltra

// MARK: - Keychain

// MARK: - GuideLoader

final class GuideLoaderTests: XCTestCase {

    private func name(of block: GuideBlock) -> String {
        switch block.kind {
        case .heading(let level): return "heading\(level)"
        case .paragraph: return "paragraph"
        case .bullet: return "bullet"
        case .numbered(let n): return "numbered\(n)"
        case .code: return "code"
        case .rule: return "rule"
        }
    }

    private func names(_ markdown: String) -> [String] {
        GuideLoader.parse(markdown).map(name(of:))
    }

    func testBundledGuideLoads() {
        let blocks = GuideLoader.load()
        XCTAssertFalse(blocks.isEmpty)
        XCTAssertNotEqual(
            String(blocks[0].text.characters),
            "Could not load the user guide.",
            "user-guide.md is not in the app target's bundle resources"
        )
    }

    func testMissingGuideShowsFallbackMessage() {
        let blocks = GuideLoader.load(named: "no-such-guide")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(String(blocks[0].text.characters), "Could not load the user guide.")
    }

    func testHeadingLevels() {
        XCTAssertEqual(names("# One\n\n## Two\n\n### Three"), ["heading1", "heading2", "heading3"])
    }

    func testParagraphsAreSeparateBlocks() {
        XCTAssertEqual(names("First paragraph.\n\nSecond paragraph."), ["paragraph", "paragraph"])
    }

    func testInlineFormattingStaysInOneBlock() {
        let blocks = GuideLoader.parse("Some **bold** and *italic* text.")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(String(blocks[0].text.characters), "Some bold and italic text.")
    }

    func testBulletList() {
        let blocks = GuideLoader.parse("- apple\n- banana")
        XCTAssertEqual(blocks.map(name(of:)), ["bullet", "bullet"])
        XCTAssertEqual(blocks.map(\.depth), [1, 1])
    }

    func testNumberedListKeepsItsNumbers() {
        XCTAssertEqual(names("1. first\n2. second\n3. third"), ["numbered1", "numbered2", "numbered3"])
    }

    func testNestedBulletHasDeeperDepth() {
        let blocks = GuideLoader.parse("- top\n  - nested")
        XCTAssertEqual(blocks.map(name(of:)), ["bullet", "bullet"])
        XCTAssertEqual(blocks.map(\.depth), [1, 2])
    }

    func testMixedDocumentKeepsOrder() {
        let markdown = "# Title\n\nIntro text.\n\n- one\n- two\n\n## Next\n\nMore text."
        XCTAssertEqual(names(markdown), ["heading1", "paragraph", "bullet", "bullet", "heading2", "paragraph"])
    }

    func testEmptyInputDoesNotCrash() {
        XCTAssertNoThrow(GuideLoader.parse(""))
    }
}

// MARK: - AppLockManager

@MainActor
final class AppLockManagerTests: XCTestCase {

    func testStartsLocked() {
        let manager = AppLockManager()
        XCTAssertFalse(manager.isUnlocked)
        XCTAssertFalse(manager.didAuthenticate)
        XCTAssertNil(manager.authError)
    }

    func testLockClearsUnlockedState() {
        let manager = AppLockManager()
        manager.isUnlocked = true
        manager.lock()
        XCTAssertFalse(manager.isUnlocked)
    }

    func testLockClearsAuthenticationInProgress() {
        let manager = AppLockManager()
        manager.didAuthenticate = true
        manager.lock()
        XCTAssertFalse(manager.didAuthenticate)
    }

    func testLockingWhileAlreadyLockedIsHarmless() {
        let manager = AppLockManager()
        manager.lock()
        manager.lock()
        XCTAssertFalse(manager.isUnlocked)
    }
}
