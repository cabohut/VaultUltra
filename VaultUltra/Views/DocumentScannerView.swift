//
//  DocumentScannerView.swift
//  VaultUltra
//
//  Created by bugs on 7/17/26.
//

import SwiftUI
import VisionKit

struct DocumentScannerView: UIViewControllerRepresentable {
    var onScanComplete: ([Data]) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScanComplete: onScanComplete, onCancel: onCancel)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScanComplete: ([Data]) -> Void
        let onCancel: () -> Void

        init(onScanComplete: @escaping ([Data]) -> Void, onCancel: @escaping () -> Void) {
            self.onScanComplete = onScanComplete
            self.onCancel = onCancel
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            var images: [Data] = []
            for pageIndex in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: pageIndex)
                if let data = image.jpegData(compressionQuality: 0.8) {
                    images.append(data)
                }
            }
            onScanComplete(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            print("Document scan failed: \(error)")
            onCancel()
        }
    }
}
