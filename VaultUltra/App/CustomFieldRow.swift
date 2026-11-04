//
//  CustomFieldRow.swift
//  VaultUltra
//
//  Created by bugs on 7/18/26.
//      11-03-2026 - Fix for Issue 6 from Claud
//      11-04-2026 - dateStorage made internal for testing
//

import SwiftUI
import CoreData

struct CustomFieldRow: View {
    @ObservedObject var field: CustomField
    let isRevealed: Bool

    static let dateStorage: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        f.timeZone = .current
        return f
    }()

    private var type: CustomFieldType {
        CustomFieldType(rawValue: field.fieldType ?? "") ?? .text
    }

    private var isMasked: Bool { field.isSensitive && !isRevealed }

    var body: some View {
        HStack {
            Text(field.key ?? "Field")
                .foregroundStyle(.secondary)

            Spacer()

            if isMasked {
                SecureField("", text: textBinding)
                    .multilineTextAlignment(.trailing)
            } else {
                switch type {
                case .date:
                    dateControl
                case .currency:
                    HStack(spacing: 2) {
                        if !field.displayValue.isEmpty {
                            Text(Locale.current.currencySymbol ?? "$")
                                .foregroundStyle(.secondary)
                        }
                        TextField("", text: textBinding)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                case .number:
                    TextField("", text: textBinding)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                case .text:
                    TextField("", text: textBinding)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }

    // MARK: - Date

    @ViewBuilder
    private var dateControl: some View {
        let raw = field.displayValue
        if raw.isEmpty {
            Button("Set Date") {
                save(Self.dateStorage.string(from: Date()))
            }
            .buttonStyle(.borderless)
        } else if let date = Self.dateStorage.date(from: raw) {
            HStack {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { date },
                        set: { save(Self.dateStorage.string(from: $0)) }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()

                Button {
                    save("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
        } else {
            // Older free-text value in a date field: keep it visible and editable
            TextField("", text: textBinding)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Saving

    private var textBinding: Binding<String> {
        Binding(
            get: { field.displayValue },
            set: { save($0) }
        )
    }

    private func save(_ newValue: String) {
        field.displayValue = newValue
        field.item?.modifiedDate = Date()
        do {
            try field.managedObjectContext?.save()
        } catch {
            print("Failed to save field value: \(error)")
        }
    }
}
