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

    @State private var isShowingNewItemSheet = false
    @State private var prefilledSuggestionTitle: String?

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
                            prefilledSuggestionTitle = suggestion
                            isShowingNewItemSheet = true
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
                        NavigationLink(value: item) {
                            Text(item.title ?? "Untitled Item")
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
                    prefilledSuggestionTitle = nil
                    isShowingNewItemSheet = true
                } label: {
                    Label("New Item", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isShowingNewItemSheet) {
            NewItemView(
                folder: folder,
                prefilledTitle: prefilledSuggestionTitle,
                onItemCreated: {
                    if let suggestion = prefilledSuggestionTitle {
                        removeSuggestion(suggestion)
                    }
                }
            )
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
}
