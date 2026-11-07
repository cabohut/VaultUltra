//
//  ItemCleanup.swift
//  VaultUltra
//
//  Created by bugs on 11/4/26.
//      11-04-2026 - moved out of FolderDetailView so it can be unit tested
//      11-05-2026 - hasNoContent also treats newlines as blank
//

import Foundation

enum ItemCleanup {
    static func hasNoContent(_ item: Item) -> Bool {
        func isBlank(_ text: String?) -> Bool {
            (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        let attachments = item.attachments as? Set<Attachment> ?? []
        let fields = item.customFields as? Set<CustomField> ?? []

        return isBlank(item.title)
            && isBlank(item.notes)
            && attachments.isEmpty
            && fields.allSatisfy { isBlank($0.stringValue) }
    }

    /// Returns the suggestion list with `suggestion` added back, in the template's original order.
    static func restoredSuggestions(_ suggestion: String, current: [String], folderName: String) -> [String] {
        guard !current.contains(suggestion) else { return current }
        let original = SmartFolderTemplates.template(forFolderName: folderName)?.suggestedItems ?? []
        return (current + [suggestion]).sorted {
            (original.firstIndex(of: $0) ?? Int.max) < (original.firstIndex(of: $1) ?? Int.max)
        }
    }
}
