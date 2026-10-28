//
//  AboutView.swift
//  VaultUltra
//
//  Created by bugs on 8/17/26.
//

import SwiftUI

struct AboutView: View {
    @State private var guideText: AttributedString = AttributedString("Loading...")

    var body: some View {
        ScrollView {
            Text(guideText)
                .padding()
        }
        .navigationTitle("Help & About")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadGuide()
        }
    }

    private func loadGuide() {
        guard let url = Bundle.main.url(forResource: "user-guide", withExtension: "md"),
              let rawText = try? String(contentsOf: url, encoding: .utf8)
        else {
            guideText = AttributedString("Could not load the user guide.")
            return
        }

        if let parsed = try? AttributedString(markdown: rawText, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            guideText = parsed
        } else {
            guideText = AttributedString(rawText)
        }
    }
}
