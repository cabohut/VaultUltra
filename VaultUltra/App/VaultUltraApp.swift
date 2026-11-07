//
//  VaultUltraApp.swift
//  VaultUltra
//
//  Created by bugs on 7/17/26.
//      11-04-2026 - UI testing launch support
//      11-05-2026 - merge duplicate smart folders at launch
//      11-06-2026 - pending edits are saved when the app leaves the foreground
//

import SwiftUI
import CoreData

@main
struct VaultApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var lockManager = AppLockManager()
    @Environment(\.scenePhase) private var scenePhase

    @State private var showSplash = !PersistenceController.isUITesting
    @State private var showPrivacyCover = false
    
    init() {
        AttachmentDetailView.clearPreviewFiles()
        PersistenceController.shared.seedSmartFoldersIfNeeded()
        PersistenceController.shared.deduplicateSmartFolders()
        
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
                    .id(lockManager.lockEpoch)

                if !lockManager.isUnlocked {
                    LockScreenView(lockManager: lockManager)
                        .background(.ultraThinMaterial)
                        .transition(.opacity)
                }
                
                if showPrivacyCover && lockManager.isUnlocked {
                    Color(.systemBackground)
                        .overlay {
                            Image("AppLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 96, height: 96)
                                .clipShape(RoundedRectangle(cornerRadius: 96 * 0.2237, style: .continuous))
                        }
                        .ignoresSafeArea()
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
                if newPhase != .active {
                    DebouncedSave.flush(PersistenceController.shared.container.viewContext)
                }
                showPrivacyCover = (newPhase != .active)
                if newPhase == .background {
                    lockManager.lock()
                }
            }
        }
    }
}
