//
//  OnDeviceExtractionTests.swift
//  VaultUltraTests
//
//  Created by bugs on 11/5/26.
//      11-04-2026 - tests the logic around the on-device model (not the model itself)
//

import XCTest
import FoundationModels
@testable import VaultUltra

final class OnDeviceExtractionTests: XCTestCase {

    // MARK: - Truncation

    func testShortTextIsNotTruncated() {
        let result = OnDeviceExtractionService.truncated("hello")
        XCTAssertEqual(result.text, "hello")
        XCTAssertFalse(result.wasTruncated)
    }

    func testTextExactlyAtTheLimitIsNotTruncated() {
        let text = String(repeating: "a", count: OnDeviceExtractionService.maxCharacters)
        let result = OnDeviceExtractionService.truncated(text)
        XCTAssertEqual(result.text.count, OnDeviceExtractionService.maxCharacters)
        XCTAssertFalse(result.wasTruncated)
    }

    func testTextOverTheLimitIsCutAndFlagged() {
        let text = String(repeating: "a", count: OnDeviceExtractionService.maxCharacters + 1)
        let result = OnDeviceExtractionService.truncated(text)
        XCTAssertEqual(result.text.count, OnDeviceExtractionService.maxCharacters)
        XCTAssertTrue(result.wasTruncated)
    }

    // MARK: - Cleanup

    func testFieldsAreTrimmedFilteredAndSorted() {
        let cleaned = OnDeviceExtractionService.cleanedFields([
            (name: "  Zip ", value: " 90001\n"),
            (name: "Bank Name", value: "First Credit Union"),
            (name: "", value: "no key"),
            (name: "Empty Value", value: "   "),
            (name: "Account Type", value: "Checking")
        ])

        XCTAssertEqual(cleaned.map(\.key), ["Account Type", "Bank Name", "Zip"])
        XCTAssertEqual(cleaned.map(\.value), ["Checking", "First Credit Union", "90001"])
    }

    func testCleanupOfEmptyInputReturnsNothing() {
        XCTAssertTrue(OnDeviceExtractionService.cleanedFields([]).isEmpty)
    }

    // MARK: - Messages

    func testErrorDescriptions() {
        XCTAssertEqual(ExtractionError.unavailable("a").errorDescription, "a")
        XCTAssertEqual(ExtractionError.failed("b").errorDescription, "b")
        XCTAssertEqual(
            ExtractionError.noContent.errorDescription,
            "No usable details were found in this document."
        )
    }

    func testUnavailableMessages() {
        XCTAssertEqual(
            OnDeviceExtractionService.message(for: .deviceNotEligible),
            "This device doesn't support Apple Intelligence."
        )
        XCTAssertEqual(
            OnDeviceExtractionService.message(for: .appleIntelligenceNotEnabled),
            "Turn on Apple Intelligence in Settings to use Extract Info."
        )
        XCTAssertEqual(
            OnDeviceExtractionService.message(for: .modelNotReady),
            "The on-device model isn't ready yet. Please try again later."
        )
    }
}
