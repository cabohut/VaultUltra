//
//  ExtractionReviewView.swift
//  VaultUltra
//
//  Created by bugs on 7/18/26.
//      11-04-2026 - now using on-device extraction

import SwiftUI
import CoreData

struct ExtractionReviewView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let item: Item
    let suggestions: [ExtractedField]
    let wasTruncated: Bool

    @State private var selectedKeys: Set<UUID>

    init(item: Item, suggestions: [ExtractedField], wasTruncated: Bool = false) {
        self.item = item
        self.suggestions = suggestions
        self.wasTruncated = wasTruncated
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
                    Text((wasTruncated ? "This document was long, so only the first part was analyzed. " : "")
                         + "Check each value against your document. Only checked fields will be added or updated. Existing fields with matching names will be overwritten.")
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
        let chosen = suggestions.filter { selectedKeys.contains($0.id) }
        ExtractionApplier.apply(chosen, to: item, context: viewContext)

        do {
            try viewContext.save()
        } catch {
            print("Failed to apply extracted fields: \(error)")
        }

        dismiss()
    }
}
