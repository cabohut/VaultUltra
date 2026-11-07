//
//  ItemDetailView.swift
//  VaultUltra
//
//  Created by bugs on 7/17/26.
//      10-30-2026 - added "Done" button
//      11-04-2026 - added using OnDeviceExtractionService
//      11-05-2026 - extraction sheet item stored once so it no longer resets
//      11-05-2026 - Scan Document is disabled when the scanner isn't supported
//      11-06-2026 - title and notes save after a pause, flushed on leaving
//

import SwiftUI
import CoreData
import PhotosUI
import UniformTypeIdentifiers
import VisionKit

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
    @State private var extractionError: String?
    @State private var extractionSheet: IdentifiableSuggestions?
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
            addAttachmentSection
            attachmentsSection
        }
        .navigationTitle(item.title?.isEmpty == false ? item.title! : "New Item")
        .onDisappear { DebouncedSave.flush(viewContext) }
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
        .sheet(item: $extractionSheet) { wrapped in
            ExtractionReviewView(
                item: item,
                suggestions: wrapped.fields,
                wasTruncated: wrapped.wasTruncated
            )
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

            TextField("Notes", text: notesBinding, axis: .vertical)
                .lineLimit(1...4)
            
            Button {
                isShowingAddField = true
            } label: {
                Label("Add Field", systemImage: "plus.circle")
                    .imageScale(.large)
            }
        } header: {
            HStack {
                if let type = item.itemType, !type.isEmpty {
                    Label(type, systemImage: ItemFieldTemplates.symbol(for: type))
                } else {
                    Text("Details")
                }
                
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

    private var addAttachmentSection: some View {
        Section {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { attachButtons }
                VStack(spacing: 12) { attachButtons }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
        } header: {
            Text("Add Attachment")
        }
    }

    @ViewBuilder
    private var attachButtons: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            AttachTile(title: "Add Photo", systemImage: "photo")
        }
        .buttonStyle(.borderless)

        Button {
            isShowingFileImporter = true
        } label: {
            AttachTile(title: "Add File", systemImage: "folder")
        }
        .buttonStyle(.borderless)

        Button {
            isShowingScanner = true
        } label: {
            AttachTile(title: "Scan Document", systemImage: "doc.viewfinder")
        }
        .buttonStyle(.borderless)
        .disabled(!VNDocumentCameraViewController.isSupported)
    }
    
    private struct AttachTile: View {
        let title: String
        let systemImage: String

        var body: some View {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title2)
                Text(title)
                    .font(.footnote)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.tint)
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
    
    private var notesBinding: Binding<String> {
        Binding(
            get: { item.notes ?? "" },
            set: { newValue in
                item.notes = newValue
                item.modifiedDate = Date()
                DebouncedSave.schedule(viewContext)
            }
        )
    }
        
    @ViewBuilder
    private var attachmentsSection: some View {
        if !attachments.isEmpty {
            Section("Attachments") {
                ForEach(attachments) { attachment in
                    let ocrText = attachment.ocrText ?? ""
                    let canExtract = OnDeviceExtractionService.isAvailable && !ocrText.isEmpty

                    HStack {
                        Button {
                            navigationPath.append(attachment)
                        } label: {
                            HStack {
                                Image(systemName: ocrText.isEmpty ? "doc.fill" : "doc.text.fill")
                                Text(attachment.fileName ?? "Attachment")
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if canExtract {
                            Button {
                                extractFields(from: ocrText)
                            } label: {
                                Label("Extract Info", systemImage: "sparkles")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.borderless)
                            .tint(.purple)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        if canExtract {
                            Button {
                                extractFields(from: ocrText)
                            } label: {
                                Label("Extract Info", systemImage: "sparkles")
                            }
                            .tint(.purple)
                        }
                    }
                }
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
                DebouncedSave.schedule(viewContext)
            }
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
        viewContext.assignStore(of: item, to: attachment)
        let type = pickerItem.supportedContentTypes.first { $0.conforms(to: .image) }
        let ext = type?.preferredFilenameExtension ?? "jpg"
        attachment.fileName = "Photo-\(UUID().uuidString.prefix(6)).\(ext)"
        attachment.mimeType = type?.preferredMIMEType ?? "image/jpeg"
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
            viewContext.assignStore(of: item, to: attachment)
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
        viewContext.assignStore(of: item, to: attachment)
        attachment.fileName = url.lastPathComponent
        let type = UTType(filenameExtension: url.pathExtension)
        attachment.mimeType = type?.preferredMIMEType ?? "application/octet-stream"
        attachment.fileData = data
        attachment.createdDate = Date()
        attachment.item = item

        do {
            try viewContext.save()
        } catch {
            print("Failed to save imported file: \(error)")
        }

        if type?.conforms(to: .image) == true {
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
                let result = try await OnDeviceExtractionService.extractFields(
                    from: ocrText,
                    existingFieldKeys: existingKeys
                )
                isExtractingFields = false
                extractionSheet = IdentifiableSuggestions(fields: result.fields, wasTruncated: result.wasTruncated)
            } catch {
                isExtractingFields = false
                extractionError = error.localizedDescription
            }
        }
    }
}

private struct IdentifiableSuggestions: Identifiable {
    let id = UUID()
    let fields: [ExtractedField]
    let wasTruncated: Bool
}
