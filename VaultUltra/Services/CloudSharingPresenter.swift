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
        sourceRect: CGRect
    ) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
            let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else {
            print("Could not find root view controller to present sharing UI")
            return
        }

        let sharingController: UICloudSharingController

        if let existingShare = SharingService.existingShare(for: folder, in: persistentContainer) {
            let containerID = persistentContainer.persistentStoreDescriptions.first?.cloudKitContainerOptions?.containerIdentifier ?? ""
            let ckContainer = CKContainer(identifier: containerID)
            sharingController = UICloudSharingController(share: existingShare, container: ckContainer)
        } else {
            sharingController = UICloudSharingController { _, completion in
                persistentContainer.share([folder], to: nil) { _, share, container, error in
                    DispatchQueue.main.async {
                        if let error {
                            completion(nil, nil, error)
                            return
                        }
                        guard let share, let container else {
                            completion(nil, nil, NSError(
                                domain: "SharingService",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "No share returned"]
                            ))
                            return
                        }
                        share[CKShare.SystemFieldKey.title] = folder.name as CKRecordValue?
                        completion(share, container, nil)
                    }
                }
            }
        }

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

        presenter.present(sharingController, animated: true)
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
