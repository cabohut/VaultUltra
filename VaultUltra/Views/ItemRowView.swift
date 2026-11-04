//
//  ItemRowView.swift
//  VaultUltra
//
//  Created by bugs on 7/22/26.
//

import SwiftUI

struct ItemRowView: View {
    @ObservedObject var item: Item

    var body: some View {
        Label {
            Text(item.title?.isEmpty == false ? item.title! : "Untitled Item")
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: ItemFieldTemplates.symbol(for: item.itemType))
        }
    }
}
