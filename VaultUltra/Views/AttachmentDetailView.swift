//
//  AttachmentDetailView.swift
//  VaultUltra
//
//  Created by bugs on 7/17/26.
//      11-05-2026 - image zoom keeps its scale between pinches, added pan and double-tap reset
//      11-06-2026 - image decoded once instead of on every body pass
//

import SwiftUI
import UniformTypeIdentifiers

struct AttachmentDetailView: View {
    let attachment: Attachment

    @State private var temporaryFileURL: URL?
    @State private var zoomScale: CGFloat = 1.0
    @State private var previewDirectory: URL?
    
    @State private var baseScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero
    @State private var image: UIImage?
    @State private var imageLoaded = false
    
    private static let previewRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("VaultPreview", isDirectory: true)

    /// Deletes every leftover decrypted preview file. Called once at launch.
    static func clearPreviewFiles() {
        try? FileManager.default.removeItem(at: previewRoot)
    }
    
    private var isImage: Bool {
        if attachment.mimeType?.hasPrefix("image/") == true { return true }
        let ext = URL(fileURLWithPath: attachment.fileName ?? "").pathExtension
        return UTType(filenameExtension: ext)?.conforms(to: .image) == true
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
                            .offset(offset)
                            .gesture(zoomGesture)
                            .simultaneousGesture(panGesture)
                            .onTapGesture(count: 2) { resetZoom() }
                    } else if imageLoaded {
                        ContentUnavailableView(
                            "Can't Load Attachment",
                            systemImage: "exclamationmark.triangle"
                        )
                    } else {
                        ProgressView()
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
            if isImage {
                if !imageLoaded {
                    image = attachment.fileData.flatMap { UIImage(data: $0) }
                    imageLoaded = true
                }
            } else if temporaryFileURL == nil {
                writeTemporaryFile()
            }
        }
        .onDisappear {
            removeTemporaryFile()
        }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                zoomScale = min(max(baseScale * value.magnification, 0.5), 6)
            }
            .onEnded { _ in
                withAnimation {
                    zoomScale = min(max(zoomScale, 1), 4)
                    if zoomScale == 1 {
                        offset = .zero
                        baseOffset = .zero
                    }
                    baseScale = zoomScale
                }
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard zoomScale > 1 else { return }
                offset = CGSize(
                    width: baseOffset.width + value.translation.width,
                    height: baseOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                baseOffset = offset
            }
    }

    private func resetZoom() {
        withAnimation {
            zoomScale = 1
            baseScale = 1
            offset = .zero
            baseOffset = .zero
        }
    }
    
    private func writeTemporaryFile() {
        guard let data = attachment.fileData else { return }

        let name = URL(fileURLWithPath: attachment.fileName ?? "Attachment").lastPathComponent
        let directory = Self.previewRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let tempURL = directory.appendingPathComponent(name.isEmpty ? "Attachment" : name)

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: tempURL, options: .completeFileProtection)
            previewDirectory = directory
            temporaryFileURL = tempURL
        } catch {
            print("Failed to write temporary file for preview: \(error)")
        }
    }

    private func removeTemporaryFile() {
        if let previewDirectory {
            try? FileManager.default.removeItem(at: previewDirectory)
        }
        previewDirectory = nil
        temporaryFileURL = nil
    }
}
