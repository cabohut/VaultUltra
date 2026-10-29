//
//  AboutView.swift
//  VaultUltra
//
//  Created by bugs on 8/17/26.
//

import SwiftUI

import SwiftUI

// MARK: - Block model

struct GuideBlock: Identifiable {
    enum Kind {
        case heading(level: Int)
        case paragraph
        case bullet
        case numbered(Int)
        case code
        case rule
    }

    let id = UUID()
    let kind: Kind
    let depth: Int              // list nesting depth (0 for non-list blocks)
    let text: AttributedString
}

// MARK: - Loader / parser

enum GuideLoader {
    static func load(named name: String = "user-guide") -> [GuideBlock] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "md"),
              let raw = try? String(contentsOf: url, encoding: .utf8)
        else {
            return [plain("Could not load the user guide.")]
        }

        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible)

        guard let parsed = try? AttributedString(markdown: raw, options: options) else {
            return [plain(raw)]
        }
        return blocks(from: parsed)
    }

    private static func plain(_ s: String) -> GuideBlock {
        GuideBlock(kind: .paragraph, depth: 0, text: AttributedString(s))
    }

    /// Groups consecutive runs that share the same innermost block identity.
    private static func blocks(from attributed: AttributedString) -> [GuideBlock] {
        var result: [GuideBlock] = []
        var currentID: Int?
        var currentKind: GuideBlock.Kind = .paragraph
        var currentDepth = 0
        var currentText = AttributedString()

        func flush() {
            guard currentID != nil else { return }
            result.append(GuideBlock(kind: currentKind, depth: currentDepth, text: currentText))
            currentID = nil
            currentText = AttributedString()
        }

        for run in attributed.runs {
            guard let components = run.presentationIntent?.components,
                  let innermost = components.first
            else { continue }

            if innermost.identity != currentID {
                flush()
                currentID = innermost.identity
                (currentKind, currentDepth) = classify(components)
            }
            currentText.append(attributed[run.range])
        }
        flush()
        return result
    }

    /// Components are ordered innermost-first, e.g. [paragraph, listItem, unorderedList].
    private static func classify(_ components: [PresentationIntent.IntentType])
        -> (GuideBlock.Kind, Int) {

        let isOrdered = components.contains { $0.kind == .orderedList }
        let depth = components.filter {
            $0.kind == .orderedList || $0.kind == .unorderedList
        }.count

        for component in components {
            switch component.kind {
            case .header(let level):
                return (.heading(level: level), 0)
            case .thematicBreak:
                return (.rule, 0)
            case .codeBlock:
                return (.code, 0)
            case .listItem(let ordinal):
                return (isOrdered ? .numbered(ordinal) : .bullet, depth)
            default:
                continue
            }
        }
        return (.paragraph, 0)
    }
}

// MARK: - View

struct AboutView: View {
    @State private var blocks: [GuideBlock] = []
    @State private var didLoad = false

    var body: some View {
        ScrollView {
            if didLoad {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(blocks) { block in
                        GuideBlockView(block: block)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .navigationTitle("Help & About")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            blocks = GuideLoader.load()
            didLoad = true
        }
    }
}

private struct GuideBlockView: View {
    let block: GuideBlock

    var body: some View {
        switch block.kind {
        case .heading(let level):
            Text(block.text)
                .font(headingFont(level))
                .padding(.top, level <= 2 ? 14 : 6)
                .accessibilityAddTraits(.isHeader)

        case .paragraph:
            Text(block.text)

        case .bullet:
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•")
                Text(block.text)
            }
            .padding(.leading, listIndent)

        case .numbered(let n):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(n).").monospacedDigit()
                Text(block.text)
            }
            .padding(.leading, listIndent)

        case .code:
            Text(block.text)
                .font(.system(.footnote, design: .monospaced))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

        case .rule:
            Divider().padding(.vertical, 6)
        }
    }

    private var listIndent: CGFloat {
        8 + CGFloat(max(block.depth - 1, 0)) * 18
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .title.bold()
        case 2: return .title2.bold()
        default: return .headline
        }
    }
}

#Preview {
    NavigationStack { AboutView() }
}
