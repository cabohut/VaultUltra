//
//  SearchView.swift
//  VaultUltra
//
//  Created by bugs on 7/17/26.
//      11-04-2026 - search query moved to ItemSearch
//      11-05-2026 - empty titles show as Untitled Item
//      11-06-2026 - search fetches once per render
//

import SwiftUI
import CoreData

struct SearchView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var searchText = ""
    @State private var navigationPath = NavigationPath()

    var body: some View {
        let results = searchResults
        NavigationStack(path: $navigationPath) {
            List {
                ForEach(results) { item in
                    Button {
                        navigationPath.append(item)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(item.title?.isEmpty == false ? item.title! : "Untitled Item")
                            if let matchingSnippet = matchSnippet(for: item) {
                                Text(matchingSnippet)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Search")
            .navigationDestination(for: Item.self) { item in
                ItemDetailView(item: item, navigationPath: $navigationPath)
            }
            .navigationDestination(for: Attachment.self) { attachment in
                AttachmentDetailView(attachment: attachment)
            }
            .searchable(text: $searchText, prompt: "Search items and documents")
            .overlay {
                if !searchText.isEmpty && results.isEmpty {                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
    }

    private var searchResults: [Item] {
        ItemSearch.results(for: searchText, in: viewContext)
    }

    private func matchSnippet(for item: Item) -> String? {
        if let notes = item.notes, notes.localizedCaseInsensitiveContains(searchText) {
            return notes
        }
        
        let fieldSet = item.customFields as? Set<CustomField> ?? []
        if let match = fieldSet.first(where: {
            !$0.isSensitive && ($0.stringValue ?? "").localizedCaseInsensitiveContains(searchText)
        }) {
            return "\(match.key ?? "Field"): \(match.stringValue ?? "")"
        }
        
        let attachmentSet = item.attachments as? Set<Attachment> ?? []
        if let matching = attachmentSet.first(where: {
            ($0.ocrText ?? "").localizedCaseInsensitiveContains(searchText)
        }) {
            return matching.ocrText
        }
        return nil
    }
}
