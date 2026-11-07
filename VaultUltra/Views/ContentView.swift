//
//  ContentView.swift
//  VaultUltra
//
//  Created by bugs on 7/17/26.
//      11-05-2026 - new folders go to the private store, reordering skips shared folders
//      11-05-2026 - deleting a folder shared with you leaves the share instead
//      11-06-2026 - folder deletion no longer checks other folders
//      11-06-2026 - shared-folder refresh only after a finished event, debounced
//      11-06-2026 - share popover anchored to the button's UIView, GeometryReader removed
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
                       .compactMap {
                           $0.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                               as? NSPersistentCloudKitContainer.Event
                       }
                       .filter { $0.endDate != nil }
                       .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
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
                Text(folderDeletionMessage)
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

            ShareFolderButton(isShared: sharedFolderIDs.contains(folder.objectID)) { anchorView in
                CloudSharingPresenter.present(
                    folder: folder,
                    persistentContainer: persistenceController.container,
                    sourceView: anchorView
                )
            }
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
        let sharedStore = persistenceController.sharedStore
        let pending = foldersPendingDeletion
        foldersPendingDeletion = []

        for folder in pending {
            if selectedFolder == folder { selectedFolder = nil }

            // Folder shared with you: leave the share, don't delete the owner's data
            if let sharedStore, folder.objectID.persistentStore === sharedStore {
                leaveShare(for: folder, in: sharedStore)
                continue
            }

            let items = folder.items as? Set<Item> ?? []
            for item in items {
                viewContext.delete(item)
            }
            viewContext.delete(folder)
        }

        do {
            try viewContext.save()
        } catch {
            print("Failed to delete folder: \(error)")
        }
    }
    
    private func leaveShare(for folder: Folder, in store: NSPersistentStore) {
        let container = persistenceController.container
        guard let share = try? container.fetchShares(matching: [folder.objectID])[folder.objectID] else {
            print("Could not find the share for this folder")
            return
        }
        container.purgeObjectsAndRecordsInZone(with: share.recordID.zoneID, in: store) { _, error in
            if let error {
                print("Failed to leave share: \(error)")
            }
        }
    }

    private var folderDeletionMessage: String {
        let sharedStore = persistenceController.sharedStore
        let incoming = foldersPendingDeletion.filter {
            sharedStore != nil && $0.objectID.persistentStore === sharedStore
        }
        if !incoming.isEmpty && incoming.count == foldersPendingDeletion.count {
            return "You'll leave this shared folder and lose access to it. The owner keeps their copy."
        }
        var message = "The folder and all items and attachments in it will be permanently deleted. If it is shared, it will be removed for everyone."
        if !incoming.isEmpty {
            message += " Folders shared with you will be left, not deleted."
        }
        return message
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
}

// MARK: - Share button anchor

private final class AnchorBox {
    weak var view: UIView?
}

private struct AnchorView: UIViewRepresentable {
    let box: AnchorBox

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        box.view = view
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        box.view = uiView
    }
}

private struct ShareFolderButton: View {
    let isShared: Bool
    let action: (UIView?) -> Void
    @State private var anchor = AnchorBox()

    var body: some View {
        Button {
            action(anchor.view)
        } label: {
            Image(systemName: isShared ? "person.2.fill" : "person.crop.circle.badge.plus")
                .foregroundStyle(isShared ? Color.green : Color.primary)
        }
        .accessibilityLabel(Text("Share folder"))
        .buttonStyle(.plain)
        .background(AnchorView(box: anchor))
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
