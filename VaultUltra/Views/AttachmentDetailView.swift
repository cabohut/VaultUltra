//
//  AttachmentDetailView.swift
//  VaultUltra
//
//  Created by bugs on 7/17/26.
//

import SwiftUI

struct AttachmentDetailView: View {
    let attachment: Attachment

    private var image: UIImage? {
        guard let data = attachment.fileData else { return nil }
        return UIImage(data: data)
    }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
            } else {
                ContentUnavailableView(
                    "Can't Load Attachment",
                    systemImage: "exclamationmark.triangle"
                )
            }
        }
        .navigationTitle(attachment.fileName ?? "Attachment")
        .navigationBarTitleDisplayMode(.inline)
    }
}
