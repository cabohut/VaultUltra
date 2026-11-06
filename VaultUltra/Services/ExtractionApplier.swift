//
//  ExtractionApplier.swift
//  VaultUltra
//
//  Created by bugs on 11/5/26.
//      11-05-2026 - moved out of ExtractionReviewView so it can be unit tested
//      11-05-2026 - key matching is case-insensitive and tracks fields created in the loop
//

import CoreData

enum ExtractionApplier {
    private static let sensitiveWords: Set<String> = [
        "number", "ssn", "social", "password", "passcode", "pin",
        "cvv", "routing", "id", "vin", "login", "license", "passport"
    ]

    /// Matches whole words, so "Provider" doesn't trip on "id". Phone numbers stay visible.
    static func looksSensitive(_ key: String) -> Bool {
        let words = key.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        guard !words.contains("phone") else { return false }
        return words.contains { sensitiveWords.contains($0) }
    }

    private static func normalized(_ key: String) -> String {
        key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Overwrites existing fields with a matching key (ignoring case and surrounding spaces),
    /// otherwise adds a new text field. If the same key appears twice, the last value wins.
    static func apply(_ fields: [ExtractedField], to item: Item, context: NSManagedObjectContext) {
        var fieldsByKey: [String: CustomField] = [:]
        for field in (item.customFields as? Set<CustomField>) ?? [] {
            let key = normalized(field.key ?? "")
            if !key.isEmpty, fieldsByKey[key] == nil {
                fieldsByKey[key] = field
            }
        }

        for suggestion in fields {
            let key = normalized(suggestion.key)
            guard !key.isEmpty else { continue }

            if let existing = fieldsByKey[key] {
                existing.displayValue = suggestion.value
            } else {
                let field = CustomField(context: context)
                context.assignStore(of: item, to: field)
                field.key = suggestion.key
                field.fieldType = CustomFieldType.text.rawValue
                field.isSensitive = looksSensitive(suggestion.key)
                field.item = item
                field.displayValue = suggestion.value
                fieldsByKey[key] = field
            }
        }

        item.modifiedDate = Date()
    }
}
