//
//  VaultUltraApp.swift
//  VaultUltra
//
//  Created by bugs on 7/17/26.
//      11-04-2026 - UI testing launch support
//

import SwiftUI
import CoreData

@main
struct VaultApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var lockManager = AppLockManager()
    @Environment(\.scenePhase) private var scenePhase

    @State private var showSplash = !PersistenceController.isUITesting
    
    init() {
        PersistenceController.shared.seedSmartFoldersIfNeeded()
        #if DEBUG
        if PersistenceController.isUITesting {
            PersistenceController.shared.restoreSuggestedItems()
        }
        #endif
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
                if showSplash {
                    SplashView {
                        withAnimation(.easeOut(duration: 0.35)) { showSplash = false }
                    }
                    .transition(.opacity)
                    .zIndex(1)
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
