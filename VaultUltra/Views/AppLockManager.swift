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

    @Published var isUnlocked = false
    @Published var authError: String?

    func authenticate() {
        let context = LAContext()
        var error: NSError?

        let reason = "Unlock Vault to access your information."

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, evalError in
                Task { @MainActor in
                    if success {
                        self.isUnlocked = true
                        self.authError = nil
                    } else {
                        self.authError = evalError?.localizedDescription ?? "Authentication failed."
                    }
                }
            }
        } else {
            authError = "Set a passcode on this device to use Vault."
        }
    }

    func lock() {
        isUnlocked = false
    }
}
