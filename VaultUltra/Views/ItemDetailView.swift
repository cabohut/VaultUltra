//
//  ItemDetailView.swift
//  VaultUltra
//
//  Created by bugs on 7/17/26.
//      10-30-2026 - added "Done" button

import SwiftUI
import CoreData
import PhotosUI

struct ItemDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var item: Item
    @Binding var navigationPath: NavigationPath

    @FetchRequest private var attachments: FetchedResults<Attachment>
    @FetchRequest private var customFields: FetchedResults<CustomField>

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isShowingScanner = false
    @State private var isShowingAddField = false
    @State private var isShowingFileImporter = false

    @State private var isExtractingFields = false
    @State private var extractionSuggestions: [ExtractedField]?
    @State private var extractionError: String?

    @State private var isSensitiveRevealed = false

    init(item: Item, navigationPath: Binding<NavigationPath>) {
        self.item = item
        self._navigationPath = navigationPath
        _attachments = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Attachment.createdDate, ascending: true)],
            predicate: NSPredicate(format: "item == %@", item)
        )
        _customFields = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \CustomField.key, ascending: true)],
            predicate: NSPredicate(format: "item == %@", item)
        )
    }

    var body: some View {
        Form {
            detailsSection
            attachmentsSection
        }
        .navigationTitle(item.title?.isEmpty == false ? item.title! : "New Item")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    if !navigationPath.isEmpty {
                        navigationPath.removeLast()
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingAddField) {
            AddCustomFieldView(item: item)
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.pdf, .image, .plainText, .item],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
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
        .sheet(item: extractionSheetBinding) { wrapped in
            ExtractionReviewView(item: item, suggestions: wrapped.fields)
        }
        .alert("Extraction Failed", isPresented: extractionErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(extractionError ?? "")
        }
        .overlay {
            if isExtractingFields {
                ProgressView("Extracting...")
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                await loadAndSavePhoto(newValue)
            }
        }
    }

    // MARK: - Sections

    private var detailsSection: some View {
        Section {
            TextField("Title", text: titleBinding)

            ForEach(customFields) { field in
                CustomFieldRow(field: field, isRevealed: isSensitiveRevealed)
                    .swipeActions(edge: .trailing) {
                        Button("Delete", role: .destructive) {
                            deleteCustomField(field)
                        }
                    }
            }

            Button {
                isShowingAddField = true
            } label: {
                Label("Add Field", systemImage: "plus.circle")
            }
        } header: {
            HStack {
                Text(item.itemType?.isEmpty == false ? item.itemType! : "Details")

                Spacer()

                if hasSensitiveFields {
                    Button {
                        isSensitiveRevealed.toggle()
                    } label: {
                        Image(systemName: isSensitiveRevealed ? "eye.slash" : "eye")
                    }
                }
            }
        }
    }

    private var hasSensitiveFields: Bool {
        customFields.contains { $0.isSensitive }
    }

    private var attachmentsSection: some View {
        Section("Attachments") {
            ForEach(attachments) { attachment in
                Button {
                    navigationPath.append(attachment)
                } label: {
                    HStack {
                        Image(systemName: attachment.ocrText?.isEmpty == false ? "doc.text.fill" : "doc.fill")
                        Text(attachment.fileName ?? "Attachment")
                    }
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    if let ocrText = attachment.ocrText, !ocrText.isEmpty {
                        Button {
                            extractFields(from: ocrText)
                        } label: {
                            Label("Extract Info", systemImage: "sparkles")
                        }
                        .tint(.purple)
                    }
                }
            }

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("Add Photo", systemImage: "photo")
            }

            Button {
                isShowingFileImporter = true
            } label: {
                Label("Attach File", systemImage: "folder")
            }

            Button {
                isShowingScanner = true
            } label: {
                Label("Scan Document", systemImage: "doc.viewfinder")
            }
        }
    }

    // MARK: - Bindings

    private var titleBinding: Binding<String> {
        Binding(
            get: { item.title ?? "" },
            set: { newValue in
                item.title = newValue
                item.modifiedDate = Date()
                do {
                    try viewContext.save()
                } catch {
                    print("Failed to save title: \(error)")
                }
            }
        )
    }

    private var extractionSheetBinding: Binding<IdentifiableSuggestions?> {
        Binding(
            get: { extractionSuggestions.map { IdentifiableSuggestions(fields: $0) } },
            set: { _ in extractionSuggestions = nil }
        )
    }

    private var extractionErrorBinding: Binding<Bool> {
        Binding(
            get: { extractionError != nil },
            set: { _ in extractionError = nil }
        )
    }

    // MARK: - delete custom field
    private func deleteCustomField(_ field: CustomField) {
        viewContext.delete(field)
        do {
            try viewContext.save()
        } catch {
            print("Failed to delete custom field: \(error)")
        }
    }
    
    // MARK: - Attachment saving

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

        await runOCR(on: attachment, imageData: data)
    }

    private func saveScannedPages(_ imageDataArray: [Data]) {
        var savedAttachments: [(Attachment, Data)] = []

        for (index, data) in imageDataArray.enumerated() {
            let attachment = Attachment(context: viewContext)
            attachment.fileName = "Scan-\(UUID().uuidString.prefix(6))-\(index + 1).jpg"
            attachment.mimeType = "image/jpeg"
            attachment.fileData = data
            attachment.createdDate = Date()
            attachment.item = item
            savedAttachments.append((attachment, data))
        }

        do {
            try viewContext.save()
        } catch {
            print("Failed to save scanned pages: \(error)")
        }

        Task {
            for (attachment, data) in savedAttachments {
                await runOCR(on: attachment, imageData: data)
            }
        }
    }

    private func runOCR(on attachment: Attachment, imageData: Data) async {
        guard let text = await OCRService.recognizeText(in: imageData), !text.isEmpty else { return }

        attachment.ocrText = text
        do {
            try viewContext.save()
        } catch {
            print("Failed to save OCR text: \(error)")
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                saveImportedFile(url)
            }
        case .failure(let error):
            print("File import failed: \(error)")
        }
    }

    private func saveImportedFile(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            print("Failed to access security-scoped resource: \(url)")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url) else {
            print("Failed to read file data: \(url)")
            return
        }

        let attachment = Attachment(context: viewContext)
        attachment.fileName = url.lastPathComponent
        attachment.mimeType = url.pathExtension.isEmpty ? "application/octet-stream" : "application/\(url.pathExtension)"
        attachment.fileData = data
        attachment.createdDate = Date()
        attachment.item = item

        do {
            try viewContext.save()
        } catch {
            print("Failed to save imported file: \(error)")
        }

        if attachment.mimeType?.contains("image") == true {
            Task {
                await runOCR(on: attachment, imageData: data)
            }
        }
    }

    // MARK: - AI extraction

    private func extractFields(from ocrText: String) {
        isExtractingFields = true
        let existingKeys = customFields.compactMap { $0.key }

        Task {
            do {
                let results = try await ClaudeExtractionService.extractFields(
                    from: ocrText,
                    existingFieldKeys: existingKeys
                )
                await MainActor.run {
                    isExtractingFields = false
                    extractionSuggestions = results
                }
            } catch {
                await MainActor.run {
                    isExtractingFields = false
                    extractionError = error.localizedDescription
                }
            }
        }
    }
}

private struct IdentifiableSuggestions: Identifiable {
    let id = UUID()
    let fields: [ExtractedField]
}
