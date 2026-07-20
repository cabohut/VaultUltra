//
//  FolderDetailView.swift
//  VaultUltra
//
//  Created by bugs on 7/17/26.
//

import SwiftUI
import CoreData

struct FolderDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var folder: Folder

    @State private var isShowingNewItemSheet = false
    @State private var navigateToItem: Item?

    private var items: [Item] {
        let set = folder.items as? Set<Item> ?? []
        return set.sorted { ($0.title ?? "") < ($1.title ?? "") }
    }

    private var pendingSuggestionsList: [String] {
        guard let pending = folder.pendingSuggestions, !pending.isEmpty else { return [] }
        return pending.split(separator: ",").map(String.init)
    }

    private var groupedItems: [(type: String, items: [Item])] {
        let grouped = Dictionary(grouping: items) { item in
            item.itemType?.isEmpty == false ? item.itemType! : "Other"
        }
        return grouped
            .sorted { lhs, rhs in
                if lhs.key == "Other" { return false }
                if rhs.key == "Other" { return true }
                return lhs.key < rhs.key
            }
            .map { (type: $0.key, items: $0.value.sorted { ($0.title ?? "") < ($1.title ?? "") }) }
    }

    var body: some View {
        List {
            if !pendingSuggestionsList.isEmpty {
                Section("Suggested Items") {
                    ForEach(pendingSuggestionsList, id: \.self) { suggestion in
                        Button {
                            createItemFromSuggestion(suggestion)
                        } label: {
                            Label(suggestion, systemImage: "plus.circle")
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Skip", role: .destructive) {
                                removeSuggestion(suggestion)
                            }
                        }
                    }
                }
            }

            ForEach(groupedItems, id: \.type) { group in
                Section(group.type) {
                    ForEach(group.items) { item in
                        Button {
                            navigateToItem = item
                        } label: {
                            Text(item.title ?? "Untitled Item")
                                .foregroundStyle(.primary)
                        }
                    }
                    .onDelete { offsets in
                        deleteItems(offsets, from: group.items)
                    }
                }
            }
        }
        .navigationTitle(folder.name ?? "Folder")
        .navigationDestination(item: $navigateToItem) { item in
            ItemDetailView(item: item)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingNewItemSheet = true
                } label: {
                    Label("New Item", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isShowingNewItemSheet) {
            NewItemView(folder: folder) { createdItem in
                navigateToItem = createdItem
            }
        }
        .overlay {
            if items.isEmpty && pendingSuggestionsList.isEmpty {
                ContentUnavailableView(
                    "No Items Yet",
                    systemImage: "tray",
                    description: Text("Tap + to add your first item to this folder.")
                )
            }
        }
    }

    private func createItemFromSuggestion(_ suggestionTitle: String) {
        let item = Item(context: viewContext)
        item.title = ""
        item.itemType = suggestionTitle
        item.createdDate = Date()
        item.modifiedDate = Date()
        item.addToFolders(folder)

        ItemFieldTemplates.applyFields(for: suggestionTitle, to: item, context: viewContext)

        do {
            try viewContext.save()
            removeSuggestion(suggestionTitle)
            navigateToItem = item
        } catch {
            print("Failed to create item from suggestion: \(error)")
        }
    }

    private func removeSuggestion(_ suggestion: String) {
        var remaining = pendingSuggestionsList
        remaining.removeAll { $0 == suggestion }
        folder.pendingSuggestions = remaining.isEmpty ? nil : remaining.joined(separator: ",")
        do {
            try viewContext.save()
        } catch {
            print("Failed to update suggestions: \(error)")
        }
    }

    private func deleteItems(_ offsets: IndexSet, from groupItems: [Item]) {
        for index in offsets {
            viewContext.delete(groupItems[index])
        }
        do {
            try viewContext.save()
        } catch {
            print("Failed to delete item: \(error)")
        }
    }
}
