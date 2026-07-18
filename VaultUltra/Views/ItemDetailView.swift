//
//  ItemDetailView.swift
//  VaultUltra
//
//  Created by bugs on 7/17/26.
//

import SwiftUI
import CoreData
import PhotosUI

struct ItemDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var item: Item

    @FetchRequest private var attachments: FetchedResults<Attachment>

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isShowingScanner = false

    init(item: Item) {
        self.item = item
        _attachments = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Attachment.createdDate, ascending: true)],
            predicate: NSPredicate(format: "item == %@", item)
        )
    }

    var body: some View {
        Form {
            Section("Details") {
                Text(item.title ?? "Untitled")
                if let type = item.itemType, !type.isEmpty {
                    Text(type)
                }
            }

            Section("Attachments") {
                ForEach(attachments) { attachment in
                    NavigationLink(value: attachment) {
                        HStack {
                            Image(systemName: "doc.fill")
                            Text(attachment.fileName ?? "Attachment")
                        }
                    }
                }

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Add Photo", systemImage: "photo")
                }

                Button {
                    isShowingScanner = true
                } label: {
                    Label("Scan Document", systemImage: "doc.viewfinder")
                }
            }
        }
        .navigationTitle(item.title ?? "Item")
        .navigationDestination(for: Attachment.self) { attachment in
            AttachmentDetailView(attachment: attachment)
        }
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                await loadAndSavePhoto(newValue)
            }
        }
        .sheet(isPresented: $isShowingScanner) {
            DocumentScannerView(
                onScanComplete: { imageDataArray in
                    saveScannedPages(imageDataArray)
                    isShowingScanner = false
                },
                onCancel: {
                    isShowingScanner = false
                }
            )
            .ignoresSafeArea()
        }
    }

    private func loadAndSavePhoto(_ pickerItem: PhotosPickerItem?) async {
        guard let pickerItem else { return }

        let data: Data?
        do {
            data = try await pickerItem.loadTransferable(type: Data.self)
        } catch {
            print("Failed to load photo data: \(error)")
            selectedPhoto = nil
            return
        }

        guard let data else {
            selectedPhoto = nil
            return
        }

        let attachment = Attachment(context: viewContext)
        attachment.fileName = "Photo-\(UUID().uuidString.prefix(6)).jpg"
        attachment.mimeType = "image/jpeg"
        attachment.fileData = data
        attachment.createdDate = Date()
        attachment.item = item

        do {
            try viewContext.save()
        } catch {
            print("Failed to save attachment: \(error)")
        }

        selectedPhoto = nil
    }

    private func saveScannedPages(_ imageDataArray: [Data]) {
        for (index, data) in imageDataArray.enumerated() {
            let attachment = Attachment(context: viewContext)
            attachment.fileName = "Scan-\(UUID().uuidString.prefix(6))-\(index + 1).jpg"
            attachment.mimeType = "image/jpeg"
            attachment.fileData = data
            attachment.createdDate = Date()
            attachment.item = item
        }

        do {
            try viewContext.save()
        } catch {
            print("Failed to save scanned pages: \(error)")
        }
    }
}
