//
//  SettingsView.swift
//  VaultUltra
//
//  Created by bugs on 7/18/26.
//

import SwiftUI

struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var isKeySaved = false
    @State private var showingDeleteConfirmation = false
    @State private var showingRestoreConfirmation = false
    @State private var restoreResult: String?

    #if DEBUG
    @State private var showingResetConfirmation = false
    #endif

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink("Help & About") {
                        AboutView()
                    }
                }

                Section {
                    Button("Restore Suggested Items") {
                        showingRestoreConfirmation = true
                    }
                    .confirmationDialog(
                        "Restore suggested items?",
                        isPresented: $showingRestoreConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Restore") { restoreSuggestions() }
                        Button("Cancel", role: .cancel) {}
                    }
                } footer: {
                    Text("Brings back skipped suggestions in your smart folders and recreates any smart folder you deleted. Types you already have an item for are not suggested again.")
                }

                Section {
                    SecureField("sk-ant-...", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button("Save Key") {
                        KeychainService.saveAPIKey(apiKey)
                        isKeySaved = true
                        apiKey = ""
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)

                    if isKeySaved || KeychainService.loadAPIKey() != nil {
                        Button("Remove Saved Key", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                        .confirmationDialog(
                            "Remove API key?",
                            isPresented: $showingDeleteConfirmation,
                            titleVisibility: .visible
                        ) {
                            Button("Remove", role: .destructive) {
                                KeychainService.deleteAPIKey()
                                isKeySaved = false
                            }
                            Button("Cancel", role: .cancel) {}
                        }
                    }
                } header: {
                    Text("Anthropic API Key")
                } footer: {
                    Text("Used only for AI-assisted field extraction from scanned documents. Stored securely on this device and never leaves it except to call Anthropic's API directly.")
                }

                #if DEBUG
                Section {
                    Button("Reset All Data", role: .destructive) {
                        showingResetConfirmation = true
                    }
                    .confirmationDialog(
                        "Delete all data?",
                        isPresented: $showingResetConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Delete Everything", role: .destructive) {
                            PersistenceController.shared.resetAllData()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This cannot be undone.")
                    }
                } header: {
                    Text("Debug")
                } footer: {
                    Text("Deletes all folders, items, attachments, and fields — locally and in CloudKit. Debug builds only.")
                }
                #endif
            }
            .navigationTitle("Settings")
            .onAppear {
                isKeySaved = KeychainService.loadAPIKey() != nil
            }
            .alert(
                "Suggested Items",
                isPresented: Binding(
                    get: { restoreResult != nil },
                    set: { if !$0 { restoreResult = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(restoreResult ?? "")
            }
        }
    }

    private func restoreSuggestions() {
        let result = PersistenceController.shared.restoreSuggestedItems()
        var parts: [String] = []
        if result.suggestions > 0 {
            parts.append("Added \(result.suggestions) suggested item\(result.suggestions == 1 ? "" : "s").")
        }
        if result.folders > 0 {
            parts.append("Recreated \(result.folders) smart folder\(result.folders == 1 ? "" : "s").")
        }
        restoreResult = parts.isEmpty
            ? "Nothing to restore. Every suggestion already has an item."
            : parts.joined(separator: " ")
    }
}
