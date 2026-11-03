//
//  StoreAssignment.swift
//  VaultUltra
//
//  Created by bugs on 11/2/26.
//

import CoreData

extension NSManagedObjectContext {
    /// Puts a newly created object in the same persistent store as an
    /// already-saved parent (e.g. a Folder or Item). Call right after creating it.
    func assignStore(of parent: NSManagedObject, to object: NSManagedObject) {
        guard let store = parent.objectID.persistentStore else { return }
        assign(object, to: store)
    }
}
