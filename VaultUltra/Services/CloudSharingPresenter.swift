//
//  CloudSharingPresenter.swift
//  VaultUltra
//
//  Created by bugs on 7/22/26.
//

import UIKit
import CloudKit
import CoreData

enum CloudSharingPresenter {
    private static var coordinator: Coordinator?

    static func present(
        folder: Folder,
        persistentContainer: NSPersistentCloudKitContainer,
        sourceRect: CGRect,
        completion: @escaping () -> Void
    ) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
            let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else {
            print("Could not find root view controller to present sharing UI")
            completion()
            return
        }
        
        // Diagnostic: Check CK account status before presenting share UI
        if let containerID = persistentContainer.persistentStoreDescriptions.first?.cloudKitContainerOptions?.containerIdentifier {
            let ckContainer = CKContainer(identifier: containerID)
            ckContainer.accountStatus { status, err in
                DispatchQueue.main.async {
                    if let err = err {
                        print("CK account status error: \(err)")
                    } else {
                        print("CK account status: \(status.rawValue)")
                    }
                }
            }
        } else {
            print("No CloudKit container identifier found in persistent store description.")
        }

        // Determine container identifier for consistency
        let containerID = persistentContainer.persistentStoreDescriptions.first?.cloudKitContainerOptions?.containerIdentifier ?? ""
        let ckContainer = CKContainer(identifier: containerID)

        // Build or fetch a share before creating the controller
        var sharingController: UICloudSharingController!

        if let existingShare = SharingService.existingShare(for: folder, in: persistentContainer) {
            print("Using existing share for folder: \(folder.objectID)")
            sharingController = UICloudSharingController(share: existingShare, container: ckContainer)
            
            let sharingCoordinator = Coordinator()
            coordinator = sharingCoordinator

            sharingController.delegate = sharingCoordinator
            sharingController.availablePermissions = [.allowReadWrite, .allowPrivate]

            var presenter = rootViewController
            while let presented = presenter.presentedViewController {
                presenter = presented
            }

            sharingController.modalPresentationStyle = .popover
            if let popover = sharingController.popoverPresentationController {
                popover.sourceView = presenter.view
                popover.sourceRect = sourceRect
                popover.delegate = sharingCoordinator
            }

            // Log and present on next run loop tick to avoid presentation conflicts
            print("Presenting UICloudSharingController now…")
            DispatchQueue.main.async {
                presenter.present(sharingController, animated: true)
                completion()
            }
        } else {
            print("No existing share. Creating a new share for folder: \(folder.objectID)")

            // Preflight: ensure the folder has a permanent ID
            if folder.objectID.isTemporaryID {
                let ctx = folder.managedObjectContext ?? persistentContainer.viewContext
                ctx.perform {
                    do {
                        try ctx.obtainPermanentIDs(for: [folder])
                        if ctx.hasChanges { try ctx.save() }
                        proceedToCreateShare()
                    } catch {
                        print("Failed to obtain permanent ID/save before sharing: \(error)")
                        completion()
                    }
                }
            } else {
                proceedToCreateShare()
            }

            func proceedToCreateShare() {
                persistentContainer.share([folder], to: nil) { _, share, container, error in
                    if let error {
                        print("Error creating share: \(error)")
                        DispatchQueue.main.async { completion() }
                        return
                    }
                    guard let share, let container else {
                        print("Share creation did not produce a share instance.")
                        DispatchQueue.main.async { completion() }
                        return
                    }

                    // Set metadata
                    share[CKShare.SystemFieldKey.title] = folder.name as CKRecordValue?

                    // Set private invites only
                    share.publicPermission = .none

                    // Save the owning context to persist the relationship
                    let owningContext = folder.managedObjectContext ?? persistentContainer.viewContext
                    owningContext.perform {
                        do {
                            if owningContext.hasChanges {
                                try owningContext.save()
                                print("Owning context saved after share creation.")
                            } else {
                                print("Owning context had no changes after share creation.")
                            }

                            // Optionally flush viewContext if it has pending changes
                            let viewCtx = persistentContainer.viewContext
                            if viewCtx !== owningContext, viewCtx.hasChanges {
                                try viewCtx.save()
                                print("viewContext saved post share creation.")
                            }

                            DispatchQueue.main.async {
                                let controller = UICloudSharingController(share: share, container: container)
                                finalizePresent(controller)
                            }
                        } catch {
                            print("Failed to save owning/view context after share creation: \(error)")
                            DispatchQueue.main.async { completion() }
                        }
                    }
                }
            }

            func finalizePresent(_ controller: UICloudSharingController) {
                sharingController = controller
                
                let sharingCoordinator = Coordinator()
                coordinator = sharingCoordinator

                sharingController.delegate = sharingCoordinator
                sharingController.availablePermissions = [.allowReadWrite, .allowPrivate]

                var presenter = rootViewController
                while let presented = presenter.presentedViewController {
                    presenter = presented
                }

                sharingController.modalPresentationStyle = .popover
                if let popover = sharingController.popoverPresentationController {
                    popover.sourceView = presenter.view
                    popover.sourceRect = sourceRect
                    popover.delegate = sharingCoordinator
                }

                // Log and present on next run loop tick to avoid presentation conflicts
                print("Presenting UICloudSharingController now…")
                DispatchQueue.main.async {
                    presenter.present(sharingController, animated: true)
                    completion()
                }
            }
        }
    }

    class Coordinator: NSObject, UICloudSharingControllerDelegate, UIPopoverPresentationControllerDelegate {
        func itemTitle(for csc: UICloudSharingController) -> String? {
            "Vault Folder"
        }

        func itemType(for csc: UICloudSharingController) -> String? {
            "com.cabohut.VaultUltra.folder"
        }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            print("Failed to save share: \(error)")
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            print("Share saved successfully")
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            print("Sharing stopped")
        }

        func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
            .none
        }

        func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
            .none
        }
    }
}
