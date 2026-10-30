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
    @State private var shareButtonFrames: [NSManagedObjectID: CGRect] = [:]
    @State private var isPreparingShare = false
    
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
        .overlay {
            if isPreparingShare {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Preparing share…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .transition(.opacity)
            }
        }
        .animation(.default, value: isPreparingShare)
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
                Image(systemName: "person.crop.circle.badge.plus")
            }
            .buttonStyle(.plain)
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
    
    private func moveFolders(from source: IndexSet, to destination: Int) {
        var reordered = folders.map { $0 }
        reordered.move(fromOffsets: source, toOffset: destination)

        for (index, folder) in reordered.enumerated() {
            folder.sortOrder = Int16(index)
        }

        do {
            try viewContext.save()
        } catch {
            print("Failed to save folder order: \(error)")
        }
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
