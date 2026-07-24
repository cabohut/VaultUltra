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
    @EnvironmentObject private var persistenceController: PersistenceController

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Folder.sortOrder, ascending: true)],
        animation: .default)
    private var folders: FetchedResults<Folder>

    @State private var selectedFolder: Folder?
    @State private var isShowingNewFolderAlert = false
    @State private var newFolderName = ""
    @State private var shareButtonFrame: CGRect = .zero
    @State private var navigationPath = NavigationPath()

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

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }

    private var folderNavigationView: some View {
        NavigationSplitView {
            List(selection: $selectedFolder) {
                ForEach(folders) { folder in
                    folderRow(folder)
                        .tag(folder)
                }
                .onDelete(perform: deleteFolders)
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
            NavigationStack(path: $navigationPath) {
                if let selectedFolder {
                    FolderDetailView(folder: selectedFolder, navigationPath: $navigationPath)
                } else {
                    Text("Select a folder")
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: selectedFolder) { _, _ in
                navigationPath = NavigationPath()
            }
        }
    }

    @ViewBuilder
    private func folderRow(_ folder: Folder) -> some View {
        HStack {
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

            Spacer()

            Button {
                CloudSharingPresenter.present(
                    folder: folder,
                    persistentContainer: persistenceController.container,
                    sourceRect: shareButtonFrame
                )
            } label: {
                Image(systemName: "person.crop.circle.badge.plus")
            }
            .buttonStyle(.plain)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            shareButtonFrame = geo.frame(in: .global)
                        }
                }
            )
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

    private func deleteFolders(at offsets: IndexSet) {
        for index in offsets {
            viewContext.delete(folders[index])
        }
        do {
            try viewContext.save()
        } catch {
            print("Failed to delete folder: \(error)")
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
