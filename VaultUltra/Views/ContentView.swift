//
//  ContentView.swift
//  VaultUltra
//
//  Created by bugs on 7/17/26.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Folder.sortOrder, ascending: true)],
        animation: .default)
    private var folders: FetchedResults<Folder>

    @State private var selectedFolder: Folder?
    @State private var isShowingNewFolderAlert = false
    @State private var newFolderName = ""

    var body: some View {
        TabView {
            folderNavigationView
                .tabItem {
                    Label("Folders", systemImage: "folder")
                }

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
        }
    }

    private var folderNavigationView: some View {
        NavigationSplitView {
            List(folders, selection: $selectedFolder) { folder in
                Label {
                    VStack(alignment: .leading) {
                        Text(folder.name ?? "Untitled Folder")
                        if folder.isSmartFolder, let pending = folder.pendingSuggestions, !pending.isEmpty {
                            let remaining = pending.split(separator: ",").count
                            Text("\(remaining) suggested item\(remaining == 1 ? "" : "s") remaining")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: folder.icon ?? "folder")
                }
                .tag(folder)
            }
            .navigationTitle("Folders")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingNewFolderAlert = true
                    } label: {
                        Label("New Folder", systemImage: "plus")
                    }
                }
            }
            .alert("New Folder", isPresented: $isShowingNewFolderAlert) {
                TextField("Folder name", text: $newFolderName)
                Button("Cancel", role: .cancel) {
                    newFolderName = ""
                }
                Button("Create") {
                    addFolder(name: newFolderName)
                    newFolderName = ""
                }
            }
        } detail: {
            NavigationStack {
                if let selectedFolder {
                    FolderDetailView(folder: selectedFolder)
                } else {
                    Text("Select a folder")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func addFolder(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        withAnimation {
            let folder = Folder(context: viewContext)
            folder.name = trimmed
            folder.icon = "folder"
            folder.isSmartFolder = false
            folder.sortOrder = Int16(folders.count)
            folder.createdDate = Date()

            do {
                try viewContext.save()
            } catch {
                print("Failed to save folder: \(error)")
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
