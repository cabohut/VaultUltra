//
//  ExtractionReviewView.swift
//  VaultUltra
//
//  Created by bugs on 7/18/26.
//

import SwiftUI
import CoreData

struct ExtractionReviewView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let item: Item
    let suggestions: [ExtractedField]

    @State private var selectedKeys: Set<UUID>

    init(item: Item, suggestions: [ExtractedField]) {
        self.item = item
        self.suggestions = suggestions
        _selectedKeys = State(initialValue: Set(suggestions.map { $0.id }))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(suggestions) { suggestion in
                        Toggle(isOn: Binding(
                            get: { selectedKeys.contains(suggestion.id) },
                            set: { isOn in
                                if isOn { selectedKeys.insert(suggestion.id) }
                                else { selectedKeys.remove(suggestion.id) }
                            }
                        )) {
                            VStack(alignment: .leading) {
                                Text(suggestion.key)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(suggestion.value)
                            }
                        }
                    }
                } header: {
                    Text("Suggested Fields")
                } footer: {
                    Text("Only checked fields will be added or updated. Existing fields with matching names will be overwritten.")
                }
            }
            .navigationTitle("Review Extraction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applySelected()
                    }
                    .disabled(selectedKeys.isEmpty)
                }
            }
        }
    }

    private func applySelected() {
        let existingFields = (item.customFields as? Set<CustomField>) ?? []

        for suggestion in suggestions where selectedKeys.contains(suggestion.id) {
            if let existing = existingFields.first(where: { $0.key == suggestion.key }) {
                existing.displayValue = suggestion.value
            } else {
                let field = CustomField(context: viewContext)
                field.key = suggestion.key
                field.fieldType = CustomFieldType.text.rawValue
                field.isSensitive = false
                field.item = item
                field.displayValue = suggestion.value
            }
        }

        item.modifiedDate = Date()

        do {
            try viewContext.save()
        } catch {
            print("Failed to apply extracted fields: \(error)")
        }

        dismiss()
    }
}
