//
//  SmartFolderTemplates.swift
//  VaultUltra
//
//  Created by bugs on 7/17/26.
//

import Foundation

struct SmartFolderTemplate {
    let name: String
    let icon: String
    let suggestedItems: [String]
}

enum SmartFolderTemplates {
    static let all: [SmartFolderTemplate] = [
        SmartFolderTemplate(
            name: "Legal",
            icon: "doc.text",
            suggestedItems: ["Will", "Power of Attorney", "Trust Documents", "Healthcare Directive"]
        ),
        SmartFolderTemplate(
            name: "Financial",
            icon: "dollarsign.circle",
            suggestedItems: ["Bank Accounts", "Investment Accounts", "Retirement Accounts", "Tax Returns"]
        ),
        SmartFolderTemplate(
            name: "Medical",
            icon: "cross.case",
            suggestedItems: ["Health Insurance Card", "Medication List", "Doctor Contacts", "Medical History"]
        ),
        SmartFolderTemplate(
            name: "IDs",
            icon: "person.text.rectangle",
            suggestedItems: ["Driver's License", "Passport", "Social Security Card", "Birth Certificate"]
        ),
        SmartFolderTemplate(
            name: "Property",
            icon: "house",
            suggestedItems: ["Home Deed", "Mortgage Documents", "Homeowner's Insurance", "Vehicle Titles"]
        ),
        SmartFolderTemplate(
            name: "Personal",
            icon: "person.crop.circle",
            suggestedItems: ["Emergency Contacts", "Last Wishes", "Digital Accounts List", "Safe Deposit Box Info"]
        )
    ]
    
    static func template(forFolderName name: String) -> SmartFolderTemplate? {
        all.first { $0.name == name }
    }
}
