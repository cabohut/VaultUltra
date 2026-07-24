//
//  VaultUltraApp.swift
//  VaultUltra
//
//  Created by bugs on 7/17/26.
//

import SwiftUI
import CoreData

@main
struct VaultApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var lockManager = AppLockManager()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        PersistenceController.shared.seedSmartFoldersIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                    .environmentObject(PersistenceController.shared)

                if !lockManager.isUnlocked {
                    LockScreenView(lockManager: lockManager)
                        .background(.ultraThinMaterial)
                        .transition(.opacity)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background {
                    lockManager.lock()
                }
            }
        }
    }
}
