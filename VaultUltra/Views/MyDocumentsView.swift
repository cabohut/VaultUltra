//
//  MyDocumentsView.swift
//  VaultUltra
//
//  Created by bugs on 11/5/26.
//      11-06-2026 - items come from a folder-filtered fetch, sorted once per render
//

import SwiftUI
import CoreData

struct MyDocumentsView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Folder.sortOrder, ascending: true)],
        animation: .default)
    private var folders: FetchedResults<Folder>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Item.createdDate, ascending: true)])
    private var allItems: FetchedResults<Item>
    
    @State private var navigationPath = NavigationPath()

    private var hasAnyItems: Bool {
        allItems.contains { $0.folder != nil }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                ForEach(folders) { folder in
                    DocumentsFolderSection(folder: folder, navigationPath: $navigationPath)
                }
            }
            .navigationTitle("Documents")
            .navigationDestination(for: Item.self) { item in
                ItemDetailView(item: item, navigationPath: $navigationPath)
            }
            .navigationDestination(for: Attachment.self) { attachment in
                AttachmentDetailView(attachment: attachment)
            }
            .overlay {
                if !hasAnyItems {
                    ContentUnavailableView(
                        "No Documents Yet",
                        systemImage: "tray",
                        description: Text("Documents you add to your folders will appear here.")
                    )
                }
            }
        }
    }
}

private struct DocumentsFolderSection: View {
    @ObservedObject var folder: Folder
    @Binding var navigationPath: NavigationPath
    @FetchRequest private var fetchedItems: FetchedResults<Item>

    init(folder: Folder, navigationPath: Binding<NavigationPath>) {
        self.folder = folder
        self._navigationPath = navigationPath
        _fetchedItems = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Item.title, ascending: true)],
            predicate: NSPredicate(format: "folder == %@", folder)
        )
    }
    
    private var items: [Item] {
        let set = folder.items as? Set<Item> ?? []
        return set.sorted {
            let t0 = ($0.itemType ?? "").isEmpty ? "\u{FFFF}" : ($0.itemType ?? "")
            let t1 = ($1.itemType ?? "").isEmpty ? "\u{FFFF}" : ($1.itemType ?? "")
            if t0 != t1 { return t0 < t1 }
            return ($0.title ?? "") < ($1.title ?? "")
        }
    }

    var body: some View {
        if !items.isEmpty {
            Section {
                ForEach(items) { item in
                    Button {
                        navigationPath.append(item)
                    } label: {
                        ItemRowView(item: item)
                    }
                }
            } header: {
                Label(folder.name ?? "Folder", systemImage: folder.icon ?? "folder")
            }
        }
    }
}
