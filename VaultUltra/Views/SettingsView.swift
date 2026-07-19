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

    var body: some View {
        NavigationStack {
            Form {
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
                    }
                } header: {
                    Text("Anthropic API Key")
                } footer: {
                    Text("Used only for AI-assisted field extraction from scanned documents. Stored securely on this device and never leaves it except to call Anthropic's API directly.")
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                isKeySaved = KeychainService.loadAPIKey() != nil
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
    }
}
