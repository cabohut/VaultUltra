//
//  ItemTemplate.swift
//  VaultUltra
//
//  Created by bugs on 7/18/26.
//

import Foundation

struct ItemTemplateField {
    let key: String
    let type: CustomFieldType
    let isSensitive: Bool
}

struct ItemTemplate: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let fields: [ItemTemplateField]
}

enum ItemTemplates {
    static let all: [ItemTemplate] = [
        ItemTemplate(name: "Bank Account", icon: "building.columns", fields: [
            ItemTemplateField(key: "Bank Name", type: .text, isSensitive: false),
            ItemTemplateField(key: "Account Number", type: .text, isSensitive: true),
            ItemTemplateField(key: "Routing Number", type: .text, isSensitive: true),
            ItemTemplateField(key: "Login Password", type: .text, isSensitive: true),
            ItemTemplateField(key: "Notes", type: .text, isSensitive: false)
        ]),
        ItemTemplate(name: "Credit Card", icon: "creditcard", fields: [
            ItemTemplateField(key: "Card Number", type: .text, isSensitive: true),
            ItemTemplateField(key: "Expiration Date", type: .date, isSensitive: false),
            ItemTemplateField(key: "CVV", type: .text, isSensitive: true),
            ItemTemplateField(key: "PIN", type: .text, isSensitive: true),
            ItemTemplateField(key: "Notes", type: .text, isSensitive: false)
        ]),
        ItemTemplate(name: "Insurance Policy", icon: "cross.case", fields: [
            ItemTemplateField(key: "Provider", type: .text, isSensitive: false),
            ItemTemplateField(key: "Policy Number", type: .text, isSensitive: true),
            ItemTemplateField(key: "Group Number", type: .text, isSensitive: false),
            ItemTemplateField(key: "Contact Phone", type: .text, isSensitive: false),
            ItemTemplateField(key: "Notes", type: .text, isSensitive: false)
        ]),
        ItemTemplate(name: "Login / Account", icon: "person.badge.key", fields: [
            ItemTemplateField(key: "Username", type: .text, isSensitive: false),
            ItemTemplateField(key: "Password", type: .text, isSensitive: true),
            ItemTemplateField(key: "Website", type: .text, isSensitive: false),
            ItemTemplateField(key: "Notes", type: .text, isSensitive: false)
        ])
    ]
}
