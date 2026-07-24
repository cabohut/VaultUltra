//
//  AttachmentDetailView.swift
//  VaultUltra
//
//  Created by bugs on 7/17/26.
//

import SwiftUI

struct AttachmentDetailView: View {
    let attachment: Attachment

    @State private var temporaryFileURL: URL?
    @State private var zoomScale: CGFloat = 1.0

    private var isImage: Bool {
        attachment.mimeType?.hasPrefix("image/") == true
    }

    private var image: UIImage? {
        guard let data = attachment.fileData else { return nil }
        return UIImage(data: data)
    }

    var body: some View {
        Group {
            if isImage {
                GeometryReader { geo in
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .scaleEffect(zoomScale)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        zoomScale = value
                                    }
                                    .onEnded { _ in
                                        withAnimation {
                                            zoomScale = max(1.0, min(zoomScale, 4.0))
                                        }
                                    }
                            )
                    } else {
                        ContentUnavailableView(
                            "Can't Load Attachment",
                            systemImage: "exclamationmark.triangle"
                        )
                    }
                }
            } else if let temporaryFileURL {
                QuickLookView(fileURL: temporaryFileURL)
            } else {
                ProgressView("Loading...")
            }
        }
        .navigationTitle(attachment.fileName ?? "Attachment")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !isImage {
                writeTemporaryFile()
            }
        }
    }

    private func writeTemporaryFile() {
        guard let data = attachment.fileData else { return }

        let fileName = attachment.fileName ?? "Attachment"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: tempURL)
            temporaryFileURL = tempURL
        } catch {
            print("Failed to write temporary file for preview: \(error)")
        }
    }
}
