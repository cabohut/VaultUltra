//
//  SplashView.swift
//  VaultUltra
//
//  Created by bugs on 11/2/26.
//

import SwiftUI

struct SplashView: View {
    /// Name of the logo in Assets.xcassets (use your Dark variant image set)
    static let logoAssetName = "AppLogoDark"

    var onFinish: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ticksIn = false
    @State private var logoIn = false
    @State private var textIn = false
    @State private var glow = false

    private let tickCount = 60
    private let ringRadius: CGFloat = 128

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0xFFA21F), Color(hex: 0xFF9400), Color(hex: 0xF07800)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Soft radial glow behind the logo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.35), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 220
                    )
                )
                .frame(width: 440, height: 440)
                .scaleEffect(glow ? 1.08 : 0.92)
                .opacity(logoIn ? 1 : 0)

            VStack(spacing: 44) {
                ZStack {
                    // Dial tick ring
                    ForEach(0..<tickCount, id: \.self) { i in
                        let isMajor = i % 5 == 0
                        Capsule()
                            .fill(.white.opacity(isMajor ? 0.95 : 0.55))
                            .frame(width: isMajor ? 3.5 : 2, height: isMajor ? 16 : 9)
                            .offset(y: -ringRadius)
                            .rotationEffect(.degrees(Double(i) / Double(tickCount) * 360))
                            .opacity(ticksIn ? 1 : 0)
                            .scaleEffect(ticksIn ? 1 : 0.4)
                            .animation(
                                reduceMotion
                                    ? .none
                                    : .spring(response: 0.45, dampingFraction: 0.7)
                                        .delay(Double(i) * 0.012),
                                value: ticksIn
                            )
                    }

                    // Real app logo from the asset catalog
                    Image(Self.logoAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 168, height: 168)
                        .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
                        .shadow(color: .black.opacity(0.28), radius: 24, y: 12)
                        .scaleEffect(logoIn ? 1 : 0.8)
                        .opacity(logoIn ? 1 : 0)
                }
                .frame(width: ringRadius * 2 + 40, height: ringRadius * 2 + 40)

                VStack(spacing: 2) {
                    Text("Family")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                    Text("Vault Ultra")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                .opacity(textIn ? 1 : 0)
                .offset(y: textIn ? 0 : 12)
            }
        }
        .task { await runSequence() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Family Vault Ultra")
    }

    private func runSequence() async {
        if reduceMotion {
            ticksIn = true; logoIn = true; textIn = true
            try? await Task.sleep(for: .seconds(0.8))
            onFinish()
            return
        }

        ticksIn = true
        withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.25)) {
            logoIn = true
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.55)) {
            textIn = true
        }
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            glow = true
        }

        try? await Task.sleep(for: .seconds(2.0))
        onFinish()
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

#Preview {
    SplashView()
}
