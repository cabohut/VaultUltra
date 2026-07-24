//
//  AppDelegate.swift
//  VaultUltra
//
//  Created by bugs on 7/22/26.
//

import UIKit
import CoreData
import CloudKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        let persistentContainer = PersistenceController.shared.container
        persistentContainer.acceptShareInvitations(
            from: [cloudKitShareMetadata],
            into: persistentContainer.persistentStoreCoordinator.persistentStores.first!
        ) { metadatas, error in
            if let error {
                print("Failed to accept share invitation: \(error)")
            } else {
                print("Successfully accepted share invitation")
            }
        }
    }
}
