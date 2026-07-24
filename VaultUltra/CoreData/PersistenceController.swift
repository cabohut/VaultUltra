//
//  PersistenceController.swift
//  VaultUltra
//
//  Created by bugs on 7/17/26.
//

import CoreData
import Combine

final class PersistenceController: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()

    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "VaultUltra")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            guard let description = container.persistentStoreDescriptions.first else {
                fatalError("Failed to retrieve a persistent store description.")
            }

            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.cabohut.VaultUltra"
            )
        }

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

    #if DEBUG
    func resetAllData() {
        let context = container.viewContext

        let entityNames = ["Folder", "Item", "Attachment", "CustomField"]

        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            deleteRequest.resultType = .resultTypeObjectIDs

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
