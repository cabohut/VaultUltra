//
//  AddCustomFieldView.swift
//  VaultUltra
//
//  Created by bugs on 7/18/26.
//

import SwiftUI
import CoreData

struct AddCustomFieldView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let item: Item

    @State private var key = ""
    @State private var value = ""
    @State private var fieldType: CustomFieldType = .text
    @State private var isSensitive = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Field name (e.g. Account Number)", text: $key)

                    Picker("Type", selection: $fieldType) {
                        ForEach(CustomFieldType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    if isSensitive {
                        SecureField("Value", text: $value)
                    } else {
                        TextField("Value", text: $value)
                    }
                }

                Section {
                    Toggle("Sensitive", isOn: $isSensitive)
                } footer: {
                    Text("Sensitive fields are masked by default in the app. All field values are encrypted at rest.")
                }
            }
            .navigationTitle("New Field")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveField()
                    }
                    .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func saveField() {
        let trimmedKey = key.trimmingCharacters(in: .whitespaces)
        guard !trimmedKey.isEmpty else { return }

        let field = CustomField(context: viewContext)
        field.key = trimmedKey
        field.fieldType = fieldType.rawValue
        field.isSensitive = isSensitive
        field.item = item
        field.displayValue = value

        do {
            try viewContext.save()
        } catch {
            print("Failed to save custom field: \(error)")
        }

        dismiss()
    }
}

