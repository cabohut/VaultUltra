//
//  NewItemView.swift
//  VaultUltra
//
//  Created by bugs on 7/18/26.
//

import SwiftUI
import CoreData

struct NewItemView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let folder: Folder
    var prefilledTitle: String?
    var onItemCreated: (() -> Void)?

    @State private var title: String
    @State private var selectedTemplate: ItemTemplate?

    init(folder: Folder, prefilledTitle: String? = nil, onItemCreated: (() -> Void)? = nil) {
        self.folder = folder
        self.prefilledTitle = prefilledTitle
        self.onItemCreated = onItemCreated
        _title = State(initialValue: prefilledTitle ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Item title", text: $title)
                }

                Section {
                    Button {
                        selectedTemplate = nil
                    } label: {
                        HStack {
                            Label("Blank Item", systemImage: "doc")
                            Spacer()
                            if selectedTemplate == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .foregroundStyle(.primary)

                    ForEach(ItemTemplates.all) { template in
                        Button {
                            selectedTemplate = template
                        } label: {
                            HStack {
                                Label(template.name, systemImage: template.icon)
                                Spacer()
                                if selectedTemplate?.id == template.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                } header: {
                    Text("Item Type")
                } footer: {
                    Text("Choosing a type pre-fills common fields for that kind of item. The type can't be changed after the item is created.")
                }
            }
            .navigationTitle("New Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createItem()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func createItem() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        let item = Item(context: viewContext)
        item.title = trimmedTitle
        item.itemType = selectedTemplate?.name
        item.createdDate = Date()
        item.modifiedDate = Date()
        item.addToFolders(folder)

        selectedTemplate?.fields.forEach { templateField in
            let field = CustomField(context: viewContext)
            field.key = templateField.key
            field.fieldType = templateField.type.rawValue
            field.isSensitive = templateField.isSensitive
            field.item = item
            field.stringValue = ""
        }

        do {
            try viewContext.save()
            onItemCreated?()
        } catch {
            print("Failed to save new item: \(error)")
        }

        dismiss()
    }
}
