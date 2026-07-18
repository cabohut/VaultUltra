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

    @FetchRequest private var items: FetchedResults<Item>

    @State private var isShowingNewItemAlert = false
    @State private var newItemTitle = ""

    init(folder: Folder) {
        self.folder = folder
        _items = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Item.title, ascending: true)],
            predicate: NSPredicate(format: "ANY folders == %@", folder)
        )
    }

    private var pendingSuggestionsList: [String] {
        guard let pending = folder.pendingSuggestions, !pending.isEmpty else { return [] }
        return pending.split(separator: ",").map(String.init)
    }

    var body: some View {
        List {
            if !pendingSuggestionsList.isEmpty {
                Section("Suggested Items") {
                    ForEach(pendingSuggestionsList, id: \.self) { suggestion in
                        Button {
                            addItem(title: suggestion)
                            removeSuggestion(suggestion)
                        } label: {
                            Label(suggestion, systemImage: "plus.circle")
                        }
                    }
                }
            }

            Section(folder.isSmartFolder ? "Items" : "") {
                ForEach(items) { item in
                    NavigationLink(value: item) {
                        VStack(alignment: .leading) {
                            Text(item.title ?? "Untitled Item")
                            if let type = item.itemType, !type.isEmpty {
                                Text(type)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(folder.name ?? "Folder")
        .navigationDestination(for: Item.self) { item in
            ItemDetailView(item: item)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingNewItemAlert = true
                } label: {
                    Label("New Item", systemImage: "plus")
                }
            }
        }
        .alert("New Item", isPresented: $isShowingNewItemAlert) {
            TextField("Item title", text: $newItemTitle)
            Button("Cancel", role: .cancel) {
                newItemTitle = ""
            }
            Button("Create") {
                addItem(title: newItemTitle)
                newItemTitle = ""
            }
        } message: {
            Text("Enter a name for this item")
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

    private func addItem(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        withAnimation {
            let item = Item(context: viewContext)
            item.title = trimmed
            item.createdDate = Date()
            item.modifiedDate = Date()
            item.addToFolders(folder)

            do {
                try viewContext.save()
            } catch {
                print("Failed to save item: \(error)")
            }
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
}
