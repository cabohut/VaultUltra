//
//  CustomField+Extensions.swift
//  VaultUltra
//
//  Created by bugs on 7/18/26.
//

import Foundation

extension CustomField {
    var displayValue: String {
        get { stringValue ?? "" }
        set { stringValue = newValue }
    }
}
