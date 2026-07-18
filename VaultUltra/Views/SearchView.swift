//
//  SearchView.swift
//  VaultUltra
//
//  Created by bugs on 7/17/26.
//

import SwiftUI
import CoreData

struct SearchView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(searchResults) { item in
                    NavigationLink(value: item) {
                        VStack(alignment: .leading) {
                            Text(item.title ?? "Untitled Item")
                            if let matchingSnippet = matchSnippet(for: item) {
                                Text(matchingSnippet)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .navigationDestination(for: Item.self) { item in
                ItemDetailView(item: item)
            }
            .searchable(text: $searchText, prompt: "Search items and documents")
            .overlay {
                if !searchText.isEmpty && searchResults.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
    }

    private var searchResults: [Item] {
        guard !searchText.isEmpty else { return [] }

        let request: NSFetchRequest<Item> = Item.fetchRequest()
        request.predicate = NSPredicate(
            format: "title CONTAINS[cd] %@ OR notes CONTAINS[cd] %@ OR ANY attachments.ocrText CONTAINS[cd] %@",
            searchText, searchText, searchText
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Item.title, ascending: true)]

        do {
            return try viewContext.fetch(request)
        } catch {
            print("Search fetch failed: \(error)")
            return []
        }
    }

    private func matchSnippet(for item: Item) -> String? {
        if let notes = item.notes, notes.localizedCaseInsensitiveContains(searchText) {
            return notes
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
