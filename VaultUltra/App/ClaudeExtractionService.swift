//
//  ClaudeExtractionService.swift
//  VaultUltra
//
//  Created by bugs on 7/18/26.
//

import Foundation

struct ExtractedField: Identifiable {
    let id = UUID()
    let key: String
    let value: String
}

enum ClaudeExtractionError: LocalizedError {
    case missingAPIKey
    case requestFailed(String)
    case noContent

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No Anthropic API key found. Add one in Settings."
        case .requestFailed(let message):
            return "Extraction failed: \(message)"
        case .noContent:
            return "Claude didn't return any usable data."
        }
    }
}

enum ClaudeExtractionService {
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    static func extractFields(from ocrText: String, existingFieldKeys: [String]) async throws -> [ExtractedField] {
        guard let apiKey = KeychainService.loadAPIKey(), !apiKey.isEmpty else {
            throw ClaudeExtractionError.missingAPIKey
        }

        let fieldHint = existingFieldKeys.isEmpty
            ? "Suggest whatever field names make sense for this document."
            : "Prefer using these existing field names where they match: \(existingFieldKeys.joined(separator: ", "))."

        let prompt = """
        Extract key information from this scanned document text as flat key-value pairs. \
        \(fieldHint) Respond with ONLY a JSON object mapping field names to string values, \
        no other text, no markdown formatting, no code fences.

        Document text:
        \(ocrText)
        """

        let requestBody: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1000,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw ClaudeExtractionError.requestFailed("HTTP \(statusCode)")
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = json["content"] as? [[String: Any]]
        else {
            throw ClaudeExtractionError.noContent
        }

        let text = content
            .compactMap { $0["text"] as? String }
            .joined()

        guard let textData = text.data(using: .utf8),
              let fieldsDict = try? JSONSerialization.jsonObject(with: textData) as? [String: String]
        else {
            throw ClaudeExtractionError.noContent
        }

        return fieldsDict.map { ExtractedField(key: $0.key, value: $0.value) }
            .sorted { $0.key < $1.key }
    }
}
