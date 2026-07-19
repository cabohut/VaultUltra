//
//  CustomFieldRow.swift
//  VaultUltra
//
//  Created by bugs on 7/18/26.
//

import SwiftUI
import CoreData

struct CustomFieldRow: View {
    @ObservedObject var field: CustomField
    @State private var isRevealed = false

    var body: some View {
        HStack {
            Text(field.key ?? "Field")
                .foregroundStyle(.secondary)

            Spacer()

            if field.isSensitive && !isRevealed {
                SecureField("", text: bindingForField)
                    .multilineTextAlignment(.trailing)
            } else {
                TextField("Value", text: bindingForField)
                    .multilineTextAlignment(.trailing)
            }

            if field.isSensitive {
                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var bindingForField: Binding<String> {
        Binding(
            get: { field.displayValue },
            set: { newValue in
                field.displayValue = newValue
                field.item?.modifiedDate = Date()
                do {
                    try field.managedObjectContext?.save()
                } catch {
                    print("Failed to save field value: \(error)")
                }
            }
        )
    }
}
