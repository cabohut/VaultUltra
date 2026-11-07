//
//  CloudSharingPresenter.swift
//  VaultUltra
//
//  Created by bugs on 7/22/26.
//      10-30-2026 - updated to fix sharing and to use a new sharing dialogue sheet
//      11-06-2026 - popover anchors to the tapped button's view
//      11-06-2026 - share is created first with a spinner, controller always opens on the existing-share path
//      11-06-2026 - share() now runs on a background context
//      11-06-2026 - busy spinner is now a presented view controller
//      11-06-2026 - AppFolder thumbnail written onto the CKShare for folder sharing
//

import UIKit
import CloudKit
import CoreData

enum CloudSharingPresenter {
    private static var coordinator: Coordinator?
    private static var isPreparing = false

    static func present(
        folder: Folder,
        persistentContainer: NSPersistentCloudKitContainer,
        sourceView: UIView?
    ) {
        guard !isPreparing else { return }

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
            let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else {
            print("Could not find root view controller to present sharing UI")
            return
        }

        let folderTitle = folder.name ?? "Vault Folder"
        let thumbnailData = UIImage(named: "AppFolder")?.pngData()

        // Already shared: open straight away
        if let existingShare = SharingService.existingShare(for: folder, in: persistentContainer) {
            let containerID = persistentContainer.persistentStoreDescriptions.first?
                .cloudKitContainerOptions?.containerIdentifier ?? ""
            show(
                share: existingShare,
                container: CKContainer(identifier: containerID),
                title: folderTitle,
                thumbnailData: thumbnailData,
                sourceView: sourceView,
                from: rootViewController
            )
            return
        }

        // Not shared yet: create the share first, then open the controller on it
        isPreparing = true
        let busy = makeBusyController()
        var busyPresenter = rootViewController
        while let presented = busyPresenter.presentedViewController {
            busyPresenter = presented
        }
        busyPresenter.present(busy, animated: false)

        let folderID = folder.objectID
        let shareStore = folder.objectID.persistentStore
        let backgroundContext = persistentContainer.newBackgroundContext()

        func finish(share: CKShare?, container: CKContainer?, error: Error?) {
            busy.dismiss(animated: false) {
                isPreparing = false

                if let error {
                    print("Failed to create share: \(error)")
                    showError(error.localizedDescription, from: rootViewController)
                    return
                }
                guard let share, let container else {
                    print("Share creation returned no share")
                    showError("Couldn't create the share. Please try again.", from: rootViewController)
                    return
                }

                show(
                    share: share,
                    container: container,
                    title: folderTitle,
                    thumbnailData: thumbnailData,
                    sourceView: sourceView,
                    from: rootViewController
                )
            }
        }

        backgroundContext.perform {
            guard let backgroundFolder = try? backgroundContext.existingObject(with: folderID) as? Folder else {
                DispatchQueue.main.async {
                    finish(share: nil, container: nil, error: NSError(
                        domain: "SharingService",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Couldn't find this folder to share."]
                    ))
                }
                return
            }

            persistentContainer.share([backgroundFolder], to: nil) { _, share, container, error in
                withExtendedLifetime(backgroundContext) {}

                guard error == nil, let share, let container, let shareStore else {
                    DispatchQueue.main.async {
                        finish(share: share, container: container, error: error)
                    }
                    return
                }

                share[CKShare.SystemFieldKey.title] = folderTitle as CKRecordValue
                if let thumbnailData {
                    share[CKShare.SystemFieldKey.thumbnailImageData] = thumbnailData as CKRecordValue
                }

                persistentContainer.persistUpdatedShare(share, in: shareStore) { updated, persistError in
                    DispatchQueue.main.async {
                        if let persistError {
                            print("Failed to persist share metadata: \(persistError)")
                        }
                        finish(share: updated ?? share, container: container, error: nil)
                    }
                }
            }
        }
    }

    // MARK: - Presenting

    private static func show(
        share: CKShare,
        container: CKContainer,
        title: String,
        thumbnailData: Data?,
        sourceView: UIView?,
        from rootViewController: UIViewController
    ) {
        let sharingController = UICloudSharingController(share: share, container: container)

        let sharingCoordinator = Coordinator(title: title, thumbnailData: thumbnailData)
        coordinator = sharingCoordinator

        sharingController.delegate = sharingCoordinator
        sharingController.availablePermissions = [.allowReadWrite, .allowPrivate]

        var presenter = rootViewController
        while let presented = presenter.presentedViewController {
            presenter = presented
        }

        sharingController.modalPresentationStyle = .popover
        if let popover = sharingController.popoverPresentationController {
            if let sourceView {
                popover.sourceView = sourceView
                popover.sourceRect = sourceView.bounds
            } else {
                popover.sourceView = presenter.view
                popover.sourceRect = CGRect(
                    x: presenter.view.bounds.midX,
                    y: presenter.view.bounds.midY,
                    width: 0,
                    height: 0
                )
            }
            popover.delegate = sharingCoordinator
        }

        presenter.present(sharingController, animated: true)
    }

    // MARK: - Busy screen and errors
    private static func makeBusyController() -> UIViewController {
        let vc = UIViewController()
        vc.modalPresentationStyle = .overFullScreen
        vc.view.backgroundColor = UIColor.black.withAlphaComponent(0.15)

        let box = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        box.layer.cornerRadius = 14
        box.clipsToBounds = true
        box.frame = CGRect(x: 0, y: 0, width: 88, height: 88)
        box.center = CGPoint(x: vc.view.bounds.midX, y: vc.view.bounds.midY)
        box.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin,
                                .flexibleLeftMargin, .flexibleRightMargin]

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.center = CGPoint(x: box.bounds.midX, y: box.bounds.midY)
        spinner.startAnimating()

        box.contentView.addSubview(spinner)
        vc.view.addSubview(box)
        return vc
    }

    private static func showError(_ message: String, from rootViewController: UIViewController) {
        var presenter = rootViewController
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        let alert = UIAlertController(title: "Sharing Failed", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        presenter.present(alert, animated: true)
    }

    // MARK: - Delegate

    class Coordinator: NSObject, UICloudSharingControllerDelegate, UIPopoverPresentationControllerDelegate {
        private let title: String
        private let thumbnailData: Data?

        init(title: String, thumbnailData: Data?) {
            self.title = title
            self.thumbnailData = thumbnailData
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            title
        }

        func itemThumbnailData(for csc: UICloudSharingController) -> Data? {
            thumbnailData
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
