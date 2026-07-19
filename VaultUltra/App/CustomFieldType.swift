//
//  CustomFieldType.swift
//  VaultUltra
//
//  Created by bugs on 7/18/26.
//

import Foundation

enum CustomFieldType: String, CaseIterable, Identifiable {
    case text
    case date
    case currency
    case number

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .text: return "Text"
        case .date: return "Date"
        case .currency: return "Currency"
        case .number: return "Number"
        }
    }
}
