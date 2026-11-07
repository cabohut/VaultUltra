//
//  NewItemView.swift
//  VaultUltra
//
//  Created by bugs on 7/18/26.
//      11-05-2026 - only smart folders use template item types
//      11-06-2026 - item.folder replaces addToFolders
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
        if folder.isSmartFolder,
           let smartTypes = SmartFolderTemplates.template(forFolderName: folder.name ?? "")?.suggestedItems,
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
                        Label(type, systemImage: ItemFieldTemplates.symbol(for: type))
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
        viewContext.assignStore(of: folder, to: item)
        item.title = ""
        item.itemType = type
        item.createdDate = Date()
        item.modifiedDate = Date()
        item.folder = folder
        
        if let type {
            ItemFieldTemplates.applyFields(for: type, to: item, folder: folder, context: viewContext)
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
