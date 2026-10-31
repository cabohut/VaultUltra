//
//  AppLockManager.swift
//  VaultUltra
//
//  Created by bugs on 7/17/26.
//

import Foundation
import Combine
import LocalAuthentication

@MainActor
final class AppLockManager: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()

    /// How long the lock screen stays up (showing "Unlocked") after a successful auth.
    static let unlockHoldDuration: Double = 0

    @Published var isUnlocked = false
    @Published var authError: String?
    /// True during the brief success hold before the vault opens.
    @Published var didAuthenticate = false

    private var isAuthenticating = false
    private let reason = "Unlock your Vault."

    /// Uses the device-owner policy: the system tries biometrics first, then
    /// offers the passcode keypad itself if biometrics fail or are unavailable.
    func authenticate() {
        guard !isAuthenticating else { return }

        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            authError = "Set a passcode on this device to use Vault."
            return
        }

        isAuthenticating = true
        authError = nil

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, evalError in
            Task { @MainActor in
                if success {
                    await self.completeUnlock()
                } else {
                    self.isAuthenticating = false
                    self.handleFailure(evalError)
                }
            }
        }
    }

    func lock() {
        isUnlocked = false
        didAuthenticate = false
    }

    private func completeUnlock() async {
        authError = nil
        didAuthenticate = true

        try? await Task.sleep(for: .seconds(Self.unlockHoldDuration))

        // lock() may have been called during the hold
        guard didAuthenticate else {
            isAuthenticating = false
            return
        }
        isUnlocked = true
        didAuthenticate = false
        isAuthenticating = false
    }

    private func handleFailure(_ error: Error?) {
        guard let laError = error as? LAError else {
            authError = error?.localizedDescription ?? "Authentication failed."
            return
        }

        switch laError.code {
        case .userCancel, .appCancel, .systemCancel:
            // Not worth an error banner; the Unlock button is still there
            break
        default:
            authError = laError.localizedDescription
        }
    }
}
