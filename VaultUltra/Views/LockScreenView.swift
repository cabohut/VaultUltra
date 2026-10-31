//
//  LockScreenView.swift
//  VaultUltra
//
//  Created by bugs on 7/17/26.
//

import SwiftUI
import LocalAuthentication

struct LockScreenView: View {
    @ObservedObject var lockManager: AppLockManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var biometry = BiometryKind.current
    @State private var shakeCount = 0

    /// Name of the logo image set in Assets.xcassets
    private let logoAssetName = "AppLogo"
    private let logoSize: CGFloat = 128

    private var isSuccess: Bool { lockManager.didAuthenticate }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer()
                header
                Spacer()
                footer
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .onAppear { lockManager.authenticate() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { biometry = .current }
        }
        .onChange(of: lockManager.authError) { _, new in
            if new != nil { shakeCount += 1 }
        }
        .sensoryFeedback(.error, trigger: lockManager.authError) { _, new in
            new != nil
        }
        .sensoryFeedback(.success, trigger: lockManager.didAuthenticate) { _, new in
            new
        }
    }

    // MARK: - Pieces

    private var background: some View {
        ZStack {
            // Opaque base so no vault content can show through
            Color(.systemBackground)
            RadialGradient(
                colors: [Color.accentColor.opacity(isSuccess ? 0.4 : 0.28), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 520
            )
            .animation(.easeInOut(duration: 0.6), value: isSuccess)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(spacing: 28) {
            logo

            VStack(spacing: 6) {
                Text("Family Vault Ultra")
                    .font(.largeTitle.bold())
                Text(isSuccess ? "Unlocked" : "Locked")
                    .font(.headline)
                    .foregroundStyle(isSuccess ? Color.accentColor : .secondary)
                    .contentTransition(.opacity)
                Text(isSuccess
                     ? "Opening your vault…"
                     : "Use \(biometry.name) to access your documents.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
                    .contentTransition(.opacity)
            }
            .animation(.snappy, value: isSuccess)
            .accessibilityElement(children: .combine)
        }
    }

    private var logo: some View {
        Image(logoAssetName)
            .resizable()
            .scaledToFit()
            .frame(width: logoSize, height: logoSize)
            // iOS app-icon corner radius is about 22.37% of the side length
            .clipShape(RoundedRectangle(cornerRadius: logoSize * 0.2237, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: logoSize * 0.2237, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
            .scaleEffect(isSuccess ? 1.06 : 1)
            .animation(.bouncy, value: isSuccess)
            .keyframeAnimator(initialValue: 0.0, trigger: shakeCount) { content, offset in
                content.offset(x: offset)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(10, duration: 0.07)
                    CubicKeyframe(-10, duration: 0.10)
                    CubicKeyframe(6, duration: 0.10)
                    CubicKeyframe(0, duration: 0.07)
                }
            }
            .accessibilityHidden(true)
    }

    private var footer: some View {
        VStack(spacing: 14) {
            if let error = lockManager.authError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.leading)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .errorBanner()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityAddTraits(.updatesFrequently)
            }

            Button {
                lockManager.authenticate()
            } label: {
                Label("Unlock with \(biometry.name)", systemImage: biometry.symbol)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .primaryLockButton()
            .controlSize(.large)
        }
        .frame(maxWidth: 420) // keeps it tidy on iPad
        .disabled(isSuccess)
        .opacity(isSuccess ? 0.4 : 1)
        .animation(.snappy, value: lockManager.authError)
        .animation(.easeInOut(duration: 0.3), value: isSuccess)
    }
}

// MARK: - iOS 26 Liquid Glass with fallbacks

private extension View {
    @ViewBuilder
    func errorBanner() -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular.tint(.red.opacity(0.2)), in: .rect(cornerRadius: 16))
        } else {
            self.background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder
    func primaryLockButton() -> some View {
        if #available(iOS 26, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
        }
    }
}

// MARK: - Biometry helper

private enum BiometryKind {
    case faceID, touchID, opticID, passcode

    static var current: BiometryKind {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .passcode
        }
        switch context.biometryType {
        case .faceID:  return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default:       return .passcode
        }
    }

    var name: String {
        switch self {
        case .faceID:   "Face ID"
        case .touchID:  "Touch ID"
        case .opticID:  "Optic ID"
        case .passcode: "Passcode"
        }
    }

    var symbol: String {
        switch self {
        case .faceID:   "faceid"
        case .touchID:  "touchid"
        case .opticID:  "opticid"
        case .passcode: "key.fill"
        }
    }
}
