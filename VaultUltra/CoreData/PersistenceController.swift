//
//  PersistenceController.swift
//  VaultUltra
//
//  Created by bugs on 7/17/26.
//      10-30-2026 - updated to add the shared store and exposes privateStore and sharedStore

import CoreData
import CloudKit
import Combine

final class PersistenceController: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()

    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    private let privateStoreURL: URL?
    private let sharedStoreURL: URL?

    var privateStore: NSPersistentStore? {
        if let privateStoreURL {
            return container.persistentStoreCoordinator.persistentStore(for: privateStoreURL)
        }
        return container.persistentStoreCoordinator.persistentStores.first
    }

    var sharedStore: NSPersistentStore? {
        guard let sharedStoreURL else { return nil }
        return container.persistentStoreCoordinator.persistentStore(for: sharedStoreURL)
    }

    init(inMemory: Bool = false) {
        let cloudContainer = NSPersistentCloudKitContainer(name: "VaultUltra")
        var privateURL: URL?
        var sharedURL: URL?

        if inMemory {
            cloudContainer.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            guard let privateDescription = cloudContainer.persistentStoreDescriptions.first,
                  let defaultURL = privateDescription.url
            else {
                fatalError("Failed to retrieve a persistent store description.")
            }

            let containerID = "iCloud.com.cabohut.VaultUltra"

            privateDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            privateDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            let privateOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: containerID)
            privateOptions.databaseScope = .private
            privateDescription.cloudKitContainerOptions = privateOptions

            let sharedDescription = NSPersistentStoreDescription(
                url: defaultURL.deletingLastPathComponent().appendingPathComponent("vaultultra-shared.sqlite")
            )
            sharedDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            sharedDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            let sharedOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: containerID)
            sharedOptions.databaseScope = .shared
            sharedDescription.cloudKitContainerOptions = sharedOptions

            cloudContainer.persistentStoreDescriptions.append(sharedDescription)

            privateURL = defaultURL
            sharedURL = sharedDescription.url
        }

        container = cloudContainer
        privateStoreURL = privateURL
        sharedStoreURL = sharedURL

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func seedSmartFoldersIfNeeded() {
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: container,
            queue: .main
        ) { notification in
            guard
                let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event,
                event.type == .import,
                event.endDate != nil,
                event.succeeded
            else { return }

            self.performSeedCheck()
        }
    }

    private func performSeedCheck() {
        let context = container.viewContext
        let request: NSFetchRequest<Folder> = Folder.fetchRequest()
        request.predicate = NSPredicate(format: "isSmartFolder == YES")
        request.affectedStores = privateStore.map { [$0] }

        let existingCount = (try? context.count(for: request)) ?? 0
        guard existingCount == 0 else { return }

        for (index, template) in SmartFolderTemplates.all.enumerated() {
            let folder = Folder(context: context)
            folder.name = template.name
            folder.icon = template.icon
            folder.isSmartFolder = true
            folder.sortOrder = Int16(index)
            folder.createdDate = Date()
            folder.pendingSuggestions = template.suggestedItems.joined(separator: ",")
        }

        do {
            try context.save()
        } catch {
            print("Failed to seed smart folders: \(error)")
        }
    }

    /// Rebuilds each smart folder's suggestion list from its template, leaving out
    /// any type that already has an item in that folder. Recreates smart folders
    /// that were deleted. Private store only.
    @discardableResult
    func restoreSuggestedItems() -> (folders: Int, suggestions: Int) {
        guard let privateStore else { return (0, 0) }
        let context = container.viewContext

        let request: NSFetchRequest<Folder> = Folder.fetchRequest()
        request.affectedStores = [privateStore]
        let privateFolders = (try? context.fetch(request)) ?? []
        var nextSortOrder = (privateFolders.map { Int($0.sortOrder) }.max() ?? -1) + 1

        var foldersCreated = 0
        var suggestionsAdded = 0

        for template in SmartFolderTemplates.all {
            let folder: Folder
            if let existing = privateFolders.first(where: { $0.name == template.name }) {
                // A custom folder that happens to share a name is left alone
                guard existing.isSmartFolder else { continue }
                folder = existing
            } else {
                folder = Folder(context: context)
                context.assign(folder, to: privateStore)
                folder.name = template.name
                folder.icon = template.icon
                folder.isSmartFolder = true
                folder.sortOrder = Int16(nextSortOrder)
                folder.createdDate = Date()
                nextSortOrder += 1
                foldersCreated += 1
            }

            let items = (folder.items as? Set<Item>) ?? []
            let existingTypes = Set(items.compactMap { $0.itemType })
            let oldPending = Set(folder.pendingSuggestions?.split(separator: ",").map(String.init) ?? [])
            let newPending = template.suggestedItems.filter { !existingTypes.contains($0) }

            suggestionsAdded += newPending.filter { !oldPending.contains($0) }.count
            folder.pendingSuggestions = newPending.isEmpty ? nil : newPending.joined(separator: ",")
        }

        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to restore suggested items: \(error)")
            }
        }
        return (foldersCreated, suggestionsAdded)
    }
    
    #if DEBUG
    func resetAllData() {
        let context = container.viewContext

        let entityNames = ["Folder", "Item", "Attachment", "CustomField"]

        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            deleteRequest.resultType = .resultTypeObjectIDs
            deleteRequest.affectedStores = privateStore.map { [$0] }

            do {
                let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
                if let objectIDs = result?.result as? [NSManagedObjectID] {
                    let changes = [NSDeletedObjectsKey: objectIDs]
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
                }
            } catch {
                print("Failed to batch delete \(entityName): \(error)")
            }
        }

        do {
            try context.save()
        } catch {
            print("Failed to save after reset: \(error)")
        }

        performSeedCheck()
    }
    #endif

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        let sampleNames = ["Legal", "Financial", "Medical", "Property"]
        for (index, name) in sampleNames.enumerated() {
            let folder = Folder(context: viewContext)
            folder.name = name
            folder.icon = "folder"
            folder.isSmartFolder = true
            folder.sortOrder = Int16(index)
            folder.createdDate = Date()
        }
        do {
            try viewContext.save()
        } catch {
            print("Failed to save preview data: \(error)")
        }
        return result
    }()
}
