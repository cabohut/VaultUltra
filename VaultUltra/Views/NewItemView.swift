//
//  NewItemView.swift
//  VaultUltra
//
//  Created by bugs on 7/18/26.
//

import SwiftUI
import CoreData

import SwiftUI
import CoreData

struct NewItemView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let folder: Folder
    var onItemCreated: ((Item) -> Void)?

    private var availableTypes: [String] {
        if let smartTypes = SmartFolderTemplates.template(forFolderName: folder.name ?? "")?.suggestedItems,
           !smartTypes.isEmpty {
            return smartTypes
        }
        return ItemFieldTemplates.genericFallbackTypes
    }

    var body: some View {
        NavigationStack {
            List {
                Button {
                    createItem(type: nil)
                } label: {
                    Label("Blank Item", systemImage: "doc")
                }
                .foregroundStyle(.primary)

                ForEach(availableTypes, id: \.self) { type in
                    Button {
                        createItem(type: type)
                    } label: {
                        Text(type)
                    }
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("New Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func createItem(type: String?) {
        let item = Item(context: viewContext)
        item.title = ""
        item.itemType = type
        item.createdDate = Date()
        item.modifiedDate = Date()
        item.addToFolders(folder)

        if let type {
            ItemFieldTemplates.applyFields(for: type, to: item, context: viewContext)
        }

        do {
            try viewContext.save()
            dismiss()
            onItemCreated?(item)
        } catch {
            print("Failed to save new item: \(error)")
        }
    }
}
