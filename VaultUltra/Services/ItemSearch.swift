//
//  ItemSearch.swift
//  VaultUltra
//
//  Created by bugs on 11/4/26.
//      11-04-2026 - moved out of SearchView so it can be unit tested
//      11-05-2026 - sensitive check treats NULL as not sensitive
//

import CoreData

enum ItemSearch {
    static func predicate(for text: String) -> NSPredicate {
        NSPredicate(
            format: "title CONTAINS[cd] %@ OR notes CONTAINS[cd] %@ OR ANY attachments.ocrText CONTAINS[cd] %@ OR SUBQUERY(customFields, $f, $f.isSensitive != YES AND $f.stringValue CONTAINS[cd] %@).@count > 0",
            text, text, text, text
        )
    }

    static func results(for text: String, in context: NSManagedObjectContext) -> [Item] {
        guard !text.isEmpty else { return [] }

        let request: NSFetchRequest<Item> = Item.fetchRequest()
        request.predicate = predicate(for: text)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Item.title, ascending: true)]

        do {
            return try context.fetch(request)
        } catch {
            print("Search fetch failed: \(error)")
            return []
        }
    }
}
