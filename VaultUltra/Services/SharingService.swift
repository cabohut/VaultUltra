//
//  SharingService.swift
//  VaultUltra
//
//  Created by bugs on 7/22/26.
//

import CoreData
import CloudKit

enum SharingService {
    static func existingShare(for folder: Folder, in persistentContainer: NSPersistentCloudKitContainer) -> CKShare? {
        try? persistentContainer.fetchShares(matching: [folder.objectID])[folder.objectID]
    }
}
