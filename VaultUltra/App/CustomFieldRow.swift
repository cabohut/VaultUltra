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
    let isRevealed: Bool

    var body: some View {
        HStack {
            Text(field.key ?? "Field")
                .foregroundStyle(.secondary)

            Spacer()

            if field.isSensitive && !isRevealed {
                SecureField("", text: bindingForField)
                    .multilineTextAlignment(.trailing)
            } else {
                TextField("", text: bindingForField)
                    .multilineTextAlignment(.trailing)
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
