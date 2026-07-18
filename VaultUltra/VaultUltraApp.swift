//
//  VaultUltraApp.swift
//  VaultUltra
//
//  Created by bugs on 7/17/26.
//

import SwiftUI
import CoreData

@main
struct VaultUltraApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
