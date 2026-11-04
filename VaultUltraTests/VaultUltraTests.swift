//
//  VaultUltraTests.swift
//  VaultUltraTests
//
//  Created by bugs on 11/4/26.
//

import XCTest
@testable import VaultUltra

final class SmokeTests: XCTestCase {
    func testTemplatesExist() {
        XCTAssertFalse(SmartFolderTemplates.all.isEmpty)
    }
}
