//
//  ContentView.swift
//  VaultUltra
//
//  Created by bugs on 7/17/26.
//      11-05-2026 - new folders go to the private store, reordering skips shared folders
//

import SwiftUI
import CoreData
import CloudKit
import Combine

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var persistenceController: PersistenceController

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Folder.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \Folder.createdDate, ascending: true)
        ],
        animation: .default)
 
    private var folders: FetchedResults<Folder>

    @State private var selectedFolder: Folder?
    @State private var isShowingNewFolderAlert = false
    @State private var newFolderName = ""
    @State private var navigationPath = NavigationPath()
    @State private var shareButtonFrames: [NSManagedObjectID: CGRect] = [:]
    @State private var sharedFolderIDs: Set<NSManagedObjectID> = []
    @State private var foldersPendingDeletion: [Folder] = []
    
    var body: some View {
        TabView {
            folderNavigationView
                .tabItem {
                    Label("Folders", systemImage: "folder")
                }

            MyDocumentsView()
                .tabItem {
                    Label("Documents", systemImage: "doc.on.doc")
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
                .onMove(perform: moveFolders)
            }
            .navigationTitle("Folders")
               .onAppear { refreshSharedFolders() }
               .onChange(of: folders.count) { _, _ in refreshSharedFolders() }
               .onReceive(
                   NotificationCenter.default
                       .publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
                       .receive(on: DispatchQueue.main)
               ) { _ in refreshSharedFolders() }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingNewFolderAlert = true
                    } label: {
                        Label("New Folder", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .navigation) {
                    EditButton()
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
            .alert(
                "Delete folder?",
                isPresented: Binding(
                    get: { !foldersPendingDeletion.isEmpty },
                    set: { if !$0 { foldersPendingDeletion = [] } }
                )
            ) {
                Button("Delete", role: .destructive) { confirmFolderDeletion() }
                Button("Cancel", role: .cancel) { foldersPendingDeletion = [] }
            } message: {
                Text("The folder and all items and attachments in it will be permanently deleted. If it is shared, it will be removed for everyone.")
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
                    .foregroundColor(.orange)
            }

            Spacer()

            Button {
                let rect = shareButtonFrames[folder.objectID] ?? fallbackSourceRect()
                CloudSharingPresenter.present(
                    folder: folder,
                    persistentContainer: persistenceController.container,
                    sourceRect: rect
                )
            } label: {
                let isShared = sharedFolderIDs.contains(folder.objectID)
                Image(systemName: isShared ? "person.2.fill" : "person.crop.circle.badge.plus")
                    .foregroundStyle(isShared ? Color.green : Color.primary)
            }
            .accessibilityLabel(Text("Share folder"))
            .buttonStyle(.plain)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            shareButtonFrames[folder.objectID] = geo.frame(in: .global)
                        }
                        .onChange(of: geo.frame(in: .global)) { _, newFrame in
                            shareButtonFrames[folder.objectID] = newFrame
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
            if let privateStore = persistenceController.privateStore {
                viewContext.assign(folder, to: privateStore)
            }
            
            folder.name = trimmed
            folder.icon = "folder"
            folder.isSmartFolder = false
            folder.sortOrder = Int16((folders.map { Int($0.sortOrder) }.max() ?? -1) + 1)
            folder.createdDate = Date()

            do {
                try viewContext.save()
            } catch {
                print("Failed to save folder: \(error)")
            }
        }
    }

    private func deleteFolders(at offsets: IndexSet) {
        foldersPendingDeletion = offsets.map { folders[$0] }
    }

    private func confirmFolderDeletion() {
        for folder in foldersPendingDeletion {
            let items = folder.items as? Set<Item> ?? []
            for item in items {
                let folderCount = (item.folders as? Set<Folder>)?.count ?? 0
                if folderCount <= 1 {
                    viewContext.delete(item)
                }
            }
            if selectedFolder == folder { selectedFolder = nil }
            viewContext.delete(folder)
        }
        foldersPendingDeletion = []
        do {
            try viewContext.save()
        } catch {
            print("Failed to delete folder: \(error)")
        }
    }
    
    private func moveFolders(from source: IndexSet, to destination: Int) {
        var reordered = folders.map { $0 }
        reordered.move(fromOffsets: source, toOffset: destination)

        let sharedStore = persistenceController.sharedStore
        for (index, folder) in reordered.enumerated() {
            // Folders shared with you belong to their owner, so don't rewrite their order
            if folder.objectID.persistentStore === sharedStore, sharedStore != nil { continue }
            folder.sortOrder = Int16(index)
        }
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to save folder order: \(error)")
        }
    }
    
    private func refreshSharedFolders() {
        let ids = folders.map(\.objectID)
        guard !ids.isEmpty,
              let shares = try? persistenceController.container.fetchShares(matching: ids)
        else { return }

        // A share with only the owner isn't really shared yet
        sharedFolderIDs = Set(shares.filter { $0.value.participants.count > 1 }.keys)
    }
    
    private func fallbackSourceRect() -> CGRect {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .first(where: { $0.isKeyWindow })?
            .bounds ?? CGRect(x: 0, y: 0, width: 400, height: 800)
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
