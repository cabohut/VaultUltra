//
//  ItemCleanup.swift
//  VaultUltra
//
//  Created by bugs on 11/4/26.
//      11-04-2026 - moved out of FolderDetailView so it can be unit tested
//

import Foundation

enum ItemCleanup {
    static func hasNoContent(_ item: Item) -> Bool {
        let titleIsEmpty = (item.title ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        let attachments = item.attachments as? Set<Attachment> ?? []
        let fields = item.customFields as? Set<CustomField> ?? []
        let allFieldsEmpty = fields.allSatisfy {
            ($0.stringValue ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        }
        let notesIsEmpty = (item.notes ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        return titleIsEmpty && notesIsEmpty && attachments.isEmpty && allFieldsEmpty
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
