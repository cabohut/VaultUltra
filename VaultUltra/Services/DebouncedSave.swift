//
//  DebouncedSave.swift
//  VaultUltra
//
//  Created by bugs on 11/6/26.
//      11-06-2026 - saves after typing pauses instead of on every keystroke
//

import CoreData

@MainActor
enum DebouncedSave {
    private static var pending: Task<Void, Never>?

    /// Saves after a pause in typing, so each keystroke doesn't trigger a CloudKit export.
    static func schedule(_ context: NSManagedObjectContext?, delay: Duration = .seconds(1)) {
        pending?.cancel()
        pending = Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            save(context)
        }
    }

    /// Saves now and cancels any pending delayed save.
    static func flush(_ context: NSManagedObjectContext?) {
        pending?.cancel()
        pending = nil
        save(context)
    }

    private static func save(_ context: NSManagedObjectContext?) {
        guard let context, context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("Failed to save: \(error)")
        }
    }
}
