//
//  FolderDetailView.swift
//  VaultUltra
//
//  Created by bugs on 7/17/26.
//      10-30-2026 - updated to delete items with blank entries and them to suggested list

import SwiftUI
import CoreData
import CloudKit

struct FolderDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var persistenceController: PersistenceController
    @ObservedObject var folder: Folder
    @Binding var navigationPath: NavigationPath

    @State private var isShowingNewItemSheet = false
    @State private var newItemRecords: [NewItemRecord] = []
    @State private var itemPendingDeletion: Item?

    private struct NewItemRecord {
        let objectID: NSManagedObjectID
        let folder: Folder
        let suggestion: String?
    }

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

    private var isShowingDeleteConfirmation: Binding<Bool> {
        Binding(
            get: { itemPendingDeletion != nil },
            set: { isPresented in
                if !isPresented { itemPendingDeletion = nil }
            }
        )
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
                            navigationPath.append(item)
                        } label: {
                            ItemRowView(item: item)
                        }
                    }
                    .onDelete { offsets in
                        requestDeletion(offsets, from: group.items)
                    }
                }
            }
        }
        .navigationTitle(folder.name ?? "Folder")
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
                newItemRecords.append(
                    NewItemRecord(objectID: createdItem.objectID, folder: folder, suggestion: nil)
                )
                navigationPath.append(createdItem)
            }
        }
        .alert(
            "Delete this item?",
            isPresented: isShowingDeleteConfirmation,
            presenting: itemPendingDeletion
        ) { item in
            Button("Delete", role: .destructive) {
                deleteConfirmed(item)
            }
            Button("Cancel", role: .cancel) {}
        } message: { item in
            Text(deletionMessage(for: item))
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
        .onChange(of: navigationPath.count) { _, newCount in
            guard newCount == 0, !newItemRecords.isEmpty else { return }
            // Wait for the screen to finish sliding away before removing the item
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                cleanUpNewItems()
            }
        }
        .navigationDestination(for: Item.self) { item in
            ItemDetailView(item: item, navigationPath: $navigationPath)
        }
        .navigationDestination(for: Attachment.self) { attachment in
            AttachmentDetailView(attachment: attachment)
        }
    }

    // MARK: - Creating items

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
            newItemRecords.append(
                NewItemRecord(objectID: item.objectID, folder: folder, suggestion: suggestionTitle)
            )
            navigationPath.append(item)
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

    // MARK: - Deleting items

    private var isFolderShared: Bool {
        guard let share = SharingService.existingShare(for: folder, in: persistenceController.container) else {
            return false
        }
        return share.participants.count > 1
    }

    private func requestDeletion(_ offsets: IndexSet, from groupItems: [Item]) {
        guard let index = offsets.first, groupItems.indices.contains(index) else { return }
        itemPendingDeletion = groupItems[index]
    }

    private func deletionMessage(for item: Item) -> String {
        let title = item.title ?? ""
        let name = title.isEmpty ? "This item" : "\"\(title)\""
        var message = "\(name) and its attachments will be permanently deleted.\n"
        if isFolderShared {
            message += "It will also be removed for all shared folders."
        }
        return message
    }

    private func deleteConfirmed(_ item: Item) {
        viewContext.delete(item)
        itemPendingDeletion = nil
        do {
            try viewContext.save()
        } catch {
            print("Failed to delete item: \(error)")
        }
    }

    // MARK: - Empty item cleanup

    private func cleanUpNewItems() {
        for record in newItemRecords {
            guard let item = try? viewContext.existingObject(with: record.objectID) as? Item,
                  hasNoContent(item)
            else { continue }

            viewContext.delete(item)
            if let suggestion = record.suggestion {
                restoreSuggestion(suggestion, in: record.folder)
            }
        }
        newItemRecords.removeAll()

        if viewContext.hasChanges {
            do {
                try viewContext.save()
            } catch {
                print("Failed to clean up empty items: \(error)")
            }
        }
    }

    private func hasNoContent(_ item: Item) -> Bool {
        let titleIsEmpty = (item.title ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        let attachments = item.attachments as? Set<Attachment> ?? []
        let fields = item.customFields as? Set<CustomField> ?? []
        let allFieldsEmpty = fields.allSatisfy {
            ($0.stringValue ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        }
        return titleIsEmpty && attachments.isEmpty && allFieldsEmpty
    }

    private func restoreSuggestion(_ suggestion: String, in targetFolder: Folder) {
        let current = targetFolder.pendingSuggestions?.split(separator: ",").map(String.init) ?? []
        guard !current.contains(suggestion) else { return }

        let original = SmartFolderTemplates.template(forFolderName: targetFolder.name ?? "")?.suggestedItems ?? []
        let restored = (current + [suggestion]).sorted {
            (original.firstIndex(of: $0) ?? Int.max) < (original.firstIndex(of: $1) ?? Int.max)
        }
        targetFolder.pendingSuggestions = restored.joined(separator: ",")
    }
}
