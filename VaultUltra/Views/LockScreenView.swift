//
//  LockScreenView.swift
//  VaultUltra
//
//  Created by bugs on 7/17/26.
//

import SwiftUI

struct LockScreenView: View {
    @ObservedObject var lockManager: AppLockManager

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Vault is Locked")
                .font(.title2)
                .fontWeight(.semibold)

            if let error = lockManager.authError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                lockManager.authenticate()
            } label: {
                Label("Unlock", systemImage: "faceid")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .onAppear {
            lockManager.authenticate()
        }
    }
}
