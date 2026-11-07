//
//  AppDelegate.swift
//  VaultUltra
//
//  Created by bugs on 7/22/26.
//      10-30-2026 - now using the correct AppDelegate for sharing to work
//      11-05-2026 - share invitations that launch the app from closed are now accepted
//

import UIKit
import CoreData
import CloudKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    // Cold launch: the share arrives in the connection options
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let metadata = connectionOptions.cloudKitShareMetadata {
            acceptShare(metadata)
        }
    }

    // App already running
    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        acceptShare(cloudKitShareMetadata)
    }

    private func acceptShare(_ metadata: CKShare.Metadata) {
        let persistence = PersistenceController.shared

        guard let sharedStore = persistence.sharedStore else {
            print("No shared persistent store available to accept share")
            return
        }

        persistence.container.acceptShareInvitations(
            from: [metadata],
            into: sharedStore
        ) { _, error in
            if let error {
                print("Failed to accept share invitation: \(error)")
            } else {
                print("Successfully accepted share invitation")
            }
        }
    }
}
