//
//  ItemFieldTemplates.swift
//  VaultUltra
//
//  Created by bugs on 7/18/26.
//

import Foundation
import CoreData

struct ItemTemplateField {
    let key: String
    let type: CustomFieldType
    let isSensitive: Bool
}

enum ItemFieldTemplates {
    private static let registry: [String: [ItemTemplateField]] = [
        // MARK: Legal
        "Will": [
            .init(key: "Attorney Name", type: .text, isSensitive: false),
            .init(key: "Attorney Phone", type: .text, isSensitive: false),
            .init(key: "Location of Original", type: .text, isSensitive: false),
            .init(key: "Executor Name", type: .text, isSensitive: false),
            .init(key: "Date Signed", type: .date, isSensitive: false)
        ],
        "Power of Attorney": [
            .init(key: "Agent Name", type: .text, isSensitive: false),
            .init(key: "Agent Phone", type: .text, isSensitive: false),
            .init(key: "Attorney Name", type: .text, isSensitive: false),
            .init(key: "Effective Date", type: .date, isSensitive: false)
        ],
        "Trust Documents": [
            .init(key: "Trust Name", type: .text, isSensitive: false),
            .init(key: "Trustee Name", type: .text, isSensitive: false),
            .init(key: "Trustee Phone", type: .text, isSensitive: false),
            .init(key: "Date Established", type: .date, isSensitive: false)
        ],
        "Healthcare Directive": [
            .init(key: "Healthcare Agent", type: .text, isSensitive: false),
            .init(key: "Agent Phone", type: .text, isSensitive: false),
            .init(key: "Physician Name", type: .text, isSensitive: false),
            .init(key: "Date Signed", type: .date, isSensitive: false)
        ],

        // MARK: Financial
        "Bank Accounts": [
            .init(key: "Bank Name", type: .text, isSensitive: false),
            .init(key: "Account Number", type: .text, isSensitive: true),
            .init(key: "Routing Number", type: .text, isSensitive: true),
            .init(key: "Login ID", type: .text, isSensitive: true),
            .init(key: "Login Password", type: .text, isSensitive: true)
        ],
        "Investment Accounts": [
            .init(key: "Institution", type: .text, isSensitive: false),
            .init(key: "Account Number", type: .text, isSensitive: true),
            .init(key: "Advisor Name", type: .text, isSensitive: false),
            .init(key: "Advisor Phone", type: .text, isSensitive: false)
        ],
        "Retirement Accounts": [
            .init(key: "Institution", type: .text, isSensitive: false),
            .init(key: "Account Number", type: .text, isSensitive: true),
            .init(key: "Account Type", type: .text, isSensitive: false),
            .init(key: "Beneficiary", type: .text, isSensitive: false)
        ],
        "Tax Returns": [
            .init(key: "Tax Year", type: .text, isSensitive: false),
            .init(key: "Accountant Name", type: .text, isSensitive: false),
            .init(key: "Accountant Phone", type: .text, isSensitive: false)
        ],

        // MARK: Medical
        "Health Insurance Card": [
            .init(key: "Provider", type: .text, isSensitive: false),
            .init(key: "Policy Number", type: .text, isSensitive: true),
            .init(key: "Group Number", type: .text, isSensitive: false),
            .init(key: "Member ID", type: .text, isSensitive: true)
        ],
        "Medication List": [
            .init(key: "Medication Name", type: .text, isSensitive: false),
            .init(key: "Dosage", type: .text, isSensitive: false),
            .init(key: "Prescribing Doctor", type: .text, isSensitive: false),
            .init(key: "Pharmacy Phone", type: .text, isSensitive: false)
        ],
        "Doctor Contacts": [
            .init(key: "Doctor Name", type: .text, isSensitive: false),
            .init(key: "Specialty", type: .text, isSensitive: false),
            .init(key: "Phone", type: .text, isSensitive: false),
            .init(key: "Address", type: .text, isSensitive: false)
        ],
        "Medical History": [
            .init(key: "Condition", type: .text, isSensitive: false),
            .init(key: "Diagnosis Date", type: .date, isSensitive: false),
            .init(key: "Treating Physician", type: .text, isSensitive: false)
        ],

        // MARK: IDs
        "Driver's License": [
            .init(key: "License Number", type: .text, isSensitive: true),
            .init(key: "State", type: .text, isSensitive: false),
            .init(key: "Expiration Date", type: .date, isSensitive: false)
        ],
        "Passport": [
            .init(key: "Passport Number", type: .text, isSensitive: true),
            .init(key: "Country", type: .text, isSensitive: false),
            .init(key: "Issue Date", type: .date, isSensitive: false),
            .init(key: "Expiration Date", type: .date, isSensitive: false)
        ],
        "Social Security Card": [
            .init(key: "Social Security Number", type: .text, isSensitive: true),
            .init(key: "Name on Card", type: .text, isSensitive: false)
        ],
        "Birth Certificate": [
            .init(key: "Full Name", type: .text, isSensitive: false),
            .init(key: "Date of Birth", type: .date, isSensitive: false),
            .init(key: "Place of Birth", type: .text, isSensitive: false),
            .init(key: "Certificate Number", type: .text, isSensitive: true)
        ],

        // MARK: Property
        "Home Deed": [
            .init(key: "Property Address", type: .text, isSensitive: false),
            .init(key: "County", type: .text, isSensitive: false),
            .init(key: "Parcel Number", type: .text, isSensitive: false),
            .init(key: "Recording Date", type: .date, isSensitive: false)
        ],
        "Mortgage Documents": [
            .init(key: "Lender Name", type: .text, isSensitive: false),
            .init(key: "Loan Number", type: .text, isSensitive: true),
            .init(key: "Monthly Payment", type: .currency, isSensitive: false),
            .init(key: "Maturity Date", type: .date, isSensitive: false)
        ],
        "Homeowner's Insurance": [
            .init(key: "Provider", type: .text, isSensitive: false),
            .init(key: "Policy Number", type: .text, isSensitive: true),
            .init(key: "Coverage Amount", type: .currency, isSensitive: false),
            .init(key: "Agent Phone", type: .text, isSensitive: false)
        ],
        "Vehicle Titles": [
            .init(key: "Vehicle", type: .text, isSensitive: false),
            .init(key: "VIN", type: .text, isSensitive: true),
            .init(key: "License Plate", type: .text, isSensitive: false),
            .init(key: "Lienholder", type: .text, isSensitive: false)
        ],

        // MARK: Personal
        "Emergency Contacts": [
            .init(key: "Name", type: .text, isSensitive: false),
            .init(key: "Relationship", type: .text, isSensitive: false),
            .init(key: "Phone", type: .text, isSensitive: false),
            .init(key: "Email", type: .text, isSensitive: false)
        ],
        "Last Wishes": [
            .init(key: "Preference", type: .text, isSensitive: false),
            .init(key: "Location", type: .text, isSensitive: false),
            .init(key: "Special Instructions", type: .text, isSensitive: false)
        ],
        "Digital Accounts List": [
            .init(key: "Service Name", type: .text, isSensitive: false),
            .init(key: "Username", type: .text, isSensitive: false),
            .init(key: "Password", type: .text, isSensitive: true),
            .init(key: "Recovery Email", type: .text, isSensitive: false)
        ],
        "Safe Deposit Box Info": [
            .init(key: "Bank Name", type: .text, isSensitive: false),
            .init(key: "Box Number", type: .text, isSensitive: false),
            .init(key: "Key Location", type: .text, isSensitive: false)
        ],

        // MARK: Generic fallback types (for custom/non-smart folders)
        "Bank Account": [
            .init(key: "Bank Name", type: .text, isSensitive: false),
            .init(key: "Account Number", type: .text, isSensitive: true),
            .init(key: "Routing Number", type: .text, isSensitive: true),
            .init(key: "Login ID", type: .text, isSensitive: true),
            .init(key: "Login Password", type: .text, isSensitive: true)
        ],
        "Credit Card": [
            .init(key: "Card Number", type: .text, isSensitive: true),
            .init(key: "Expiration Date", type: .date, isSensitive: false),
            .init(key: "CVV", type: .text, isSensitive: true),
            .init(key: "PIN", type: .text, isSensitive: true)
        ],
        "Insurance Policy": [
            .init(key: "Provider", type: .text, isSensitive: false),
            .init(key: "Policy Number", type: .text, isSensitive: true),
            .init(key: "Group Number", type: .text, isSensitive: false),
            .init(key: "Contact Phone", type: .text, isSensitive: false)
        ],
        "Account Login": [
            .init(key: "Username", type: .text, isSensitive: false),
            .init(key: "Password", type: .text, isSensitive: true),
            .init(key: "Website", type: .text, isSensitive: false)
        ]
    ]

    static func fields(for typeName: String) -> [ItemTemplateField]? {
        registry[typeName]
    }

    static func applyFields(for typeName: String, to item: Item, context: NSManagedObjectContext) {
        guard let fields = fields(for: typeName) else { return }
        for templateField in fields {
            let field = CustomField(context: context)
            field.key = templateField.key
            field.fieldType = templateField.type.rawValue
            field.isSensitive = templateField.isSensitive
            field.item = item
            field.stringValue = ""
        }
    }

    /// Generic types available in folders without their own suggested item list (custom folders).
    static let genericFallbackTypes = ["Bank Account", "Credit Card", "Insurance Policy", "Login / Account"]
}
