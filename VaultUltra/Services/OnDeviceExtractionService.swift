//
//  OnDeviceExtractionService.swift
//  VaultUltra
//
//  Created by bugs on 11/4/26.
//

import Foundation
import FoundationModels

struct ExtractedField: Identifiable {
    let id = UUID()
    let key: String
    let value: String
}

struct ExtractionResult {
    let fields: [ExtractedField]
    let wasTruncated: Bool
}

enum ExtractionError: LocalizedError {
    case unavailable(String)
    case failed(String)
    case noContent

    var errorDescription: String? {
        switch self {
        case .unavailable(let message), .failed(let message):
            return message
        case .noContent:
            return "No usable details were found in this document."
        }
    }
}

@Generable
private struct GeneratedFieldList {
    @Guide(description: "Key facts found in the document, such as names, account or policy numbers, dates, and phone numbers")
    var fields: [GeneratedField]
}

@Generable
private struct GeneratedField {
    @Guide(description: "Short field name, such as Policy Number")
    var name: String
    @Guide(description: "The value exactly as written in the document")
    var value: String
}

enum OnDeviceExtractionService {
    /// The on-device model has a small context window (about 4,096 tokens shared
    /// between the prompt and the answer), so long scans are cut to this length.
    private static let maxCharacters = 6000

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    static func extractFields(from ocrText: String, existingFieldKeys: [String]) async throws -> ExtractionResult {
        if case .unavailable(let reason) = SystemLanguageModel.default.availability {
            throw ExtractionError.unavailable(message(for: reason))
        }

        let wasTruncated = ocrText.count > maxCharacters
        let text = wasTruncated ? String(ocrText.prefix(maxCharacters)) : ocrText

        let fieldHint = existingFieldKeys.isEmpty
            ? "Choose short, clear field names."
            : "Prefer these existing field names where they match: \(existingFieldKeys.joined(separator: ", "))."

        let instructions = """
        You extract key information from text scanned from a personal document. \
        Only return details that are clearly present in the text. Never guess or invent values. \
        \(fieldHint)
        """

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(
                to: "Document text:\n\(text)",
                generating: GeneratedFieldList.self
            )

            let fields = response.content.fields
                .map { ExtractedField(
                    key: $0.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    value: $0.value.trimmingCharacters(in: .whitespacesAndNewlines)
                ) }
                .filter { !$0.key.isEmpty && !$0.value.isEmpty }
                .sorted { $0.key < $1.key }

            guard !fields.isEmpty else { throw ExtractionError.noContent }
            return ExtractionResult(fields: fields, wasTruncated: wasTruncated)
        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .exceededContextWindowSize:
                throw ExtractionError.failed("This document is too long for on-device analysis.")
            case .guardrailViolation:
                throw ExtractionError.failed("Apple's on-device model couldn't process this document.")
            case .unsupportedLanguageOrLocale:
                throw ExtractionError.failed("This document's language isn't supported for on-device analysis.")
            default:
                throw ExtractionError.failed("The on-device model couldn't process this document. Please try again.")
            }
        }
    }

    private static func message(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "This device doesn't support Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in Settings to use Extract Info."
        case .modelNotReady:
            return "The on-device model isn't ready yet. Please try again later."
        @unknown default:
            return "The on-device model isn't available right now."
        }
    }
}
