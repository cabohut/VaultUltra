//
//  ClaudeExtractionServiceTests.swift
//  VaultUltraTests
//
//  Created by bugs on 11/4/26.
//      11-04-2026 - tests extraction response parsing with a stubbed URLSession
//

import XCTest
@testable import VaultUltra

// MARK: - Stub

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Tests

final class ClaudeExtractionServiceTests: XCTestCase {

    private var session: URLSession!
    private var originalKey: String?

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)

        // The simulator's real saved key is put back in tearDown
        originalKey = KeychainService.loadAPIKey()
        KeychainService.saveAPIKey("sk-ant-test-key")
    }

    override func tearDown() {
        MockURLProtocol.handler = nil
        KeychainService.deleteAPIKey()
        if let originalKey {
            KeychainService.saveAPIKey(originalKey)
        }
        super.tearDown()
    }

    // MARK: Helpers

    /// Stubs one API reply whose text block(s) hold `texts`.
    private func stub(status: Int = 200, texts: [String]) {
        let content = texts.map { ["type": "text", "text": $0] }
        let body = try! JSONSerialization.data(withJSONObject: ["content": content])
        stubRaw(status: status, body: body)
    }

    private func stubRaw(status: Int = 200, body: Data) {
        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil
            )!
            return (response, body)
        }
    }

    private func extract(keys: [String] = []) async throws -> [ExtractedField] {
        try await ClaudeExtractionService.extractFields(
            from: "some ocr text", existingFieldKeys: keys, session: session
        )
    }

    private func error() async -> Error? {
        do {
            _ = try await extract()
            return nil
        } catch {
            return error
        }
    }

    // MARK: Success

    func testParsesFieldsAndSortsThemByKey() async throws {
        stub(texts: [#"{"Zip":"90001","Bank Name":"First Credit Union","Account Type":"Checking"}"#])

        let fields = try await extract()

        XCTAssertEqual(fields.map(\.key), ["Account Type", "Bank Name", "Zip"])
        XCTAssertEqual(fields.map(\.value), ["Checking", "First Credit Union", "90001"])
    }

    func testMultipleTextBlocksAreJoinedBeforeParsing() async throws {
        stub(texts: [#"{"Name":"#, #""Pat"}"#])

        let fields = try await extract()

        XCTAssertEqual(fields.map(\.key), ["Name"])
        XCTAssertEqual(fields.map(\.value), ["Pat"])
    }

    func testEmptyObjectReturnsNoFields() async throws {
        stub(texts: ["{}"])
        let fields = try await extract()
        XCTAssertTrue(fields.isEmpty)
    }

    // MARK: Request

    func testRequestUsesExpectedEndpointAndHeaders() async throws {
        var captured: URLRequest?
        MockURLProtocol.handler = { request in
            captured = request
            let body = try JSONSerialization.data(
                withJSONObject: ["content": [["type": "text", "text": "{}"]]]
            )
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, body)
        }

        _ = try await extract(keys: ["Bank Name"])

        let request = try XCTUnwrap(captured)
        XCTAssertEqual(request.url?.absoluteString, "https://api.anthropic.com/v1/messages")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "sk-ant-test-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    // MARK: Failures

    func testMissingKeyThrowsBeforeAnyRequest() async {
        KeychainService.deleteAPIKey()
        var requestMade = false
        MockURLProtocol.handler = { request in
            requestMade = true
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let thrown = await error()

        guard case .missingAPIKey? = thrown as? ClaudeExtractionError else {
            return XCTFail("Expected missingAPIKey, got \(String(describing: thrown))")
        }
        XCTAssertFalse(requestMade)
    }

    func testEmptyKeyIsTreatedAsMissing() async {
        KeychainService.saveAPIKey("")

        let thrown = await error()

        guard case .missingAPIKey? = thrown as? ClaudeExtractionError else {
            return XCTFail("Expected missingAPIKey, got \(String(describing: thrown))")
        }
    }

    func testHTTPErrorReportsTheStatusCode() async {
        stub(status: 401, texts: ["{}"])

        let thrown = await error()

        guard case .requestFailed(let message)? = thrown as? ClaudeExtractionError else {
            return XCTFail("Expected requestFailed, got \(String(describing: thrown))")
        }
        XCTAssertEqual(message, "HTTP 401")
    }

    func testBodyWithoutContentArrayThrowsNoContent() async {
        stubRaw(body: Data(#"{"error":"nope"}"#.utf8))

        let thrown = await error()

        guard case .noContent? = thrown as? ClaudeExtractionError else {
            return XCTFail("Expected noContent, got \(String(describing: thrown))")
        }
    }

    func testReplyThatIsNotJSONThrowsNoContent() async {
        stub(texts: ["Sorry, I could not find any fields."])

        let thrown = await error()

        guard case .noContent? = thrown as? ClaudeExtractionError else {
            return XCTFail("Expected noContent, got \(String(describing: thrown))")
        }
    }

    func testCodeFencedJSONCurrentlyThrowsNoContent() async {
        // Documents current behavior: the prompt forbids fences, but a fenced reply is not rescued.
        stub(texts: ["```json\n{\"Name\":\"Pat\"}\n```"])

        let thrown = await error()

        guard case .noContent? = thrown as? ClaudeExtractionError else {
            return XCTFail("Expected noContent, got \(String(describing: thrown))")
        }
    }

    func testNonStringValuesCurrentlyThrowNoContent() async {
        // Documents current behavior: one number in the object rejects the whole reply.
        stub(texts: [#"{"Name":"Pat","Age":42}"#])

        let thrown = await error()

        guard case .noContent? = thrown as? ClaudeExtractionError else {
            return XCTFail("Expected noContent, got \(String(describing: thrown))")
        }
    }

    func testNetworkFailureIsPropagated() async {
        MockURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }

        let thrown = await error()

        XCTAssertEqual((thrown as? URLError)?.code, .notConnectedToInternet)
    }

    // MARK: Messages

    func testErrorDescriptionsAreUserFriendly() {
        XCTAssertEqual(
            ClaudeExtractionError.missingAPIKey.errorDescription,
            "No Anthropic API key found. Add one in Settings."
        )
        XCTAssertEqual(
            ClaudeExtractionError.requestFailed("HTTP 500").errorDescription,
            "Extraction failed: HTTP 500"
        )
        XCTAssertEqual(
            ClaudeExtractionError.noContent.errorDescription,
            "Claude didn't return any usable data."
        )
    }
}
