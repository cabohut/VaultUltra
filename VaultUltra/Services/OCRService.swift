//
//  OCRService.swift
//  VaultUltra
//
//  Created by bugs on 7/17/26.
//      11-05-2026 - fixed image orientation, removed continuation, runs off the main actor
//

import Foundation
import Vision
import UIKit
import ImageIO

enum OCRService {
    @concurrent
    static func recognizeText(in imageData: Data) async -> String? {
        guard let image = UIImage(data: imageData),
              let cgImage = image.cgImage
        else { return nil }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: orientation(for: image.imageOrientation),
            options: [:]
        )

        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform OCR request: \(error)")
            return nil
        }

        guard let observations = request.results else { return nil }
        return observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }

    nonisolated private static func orientation(for orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .upMirrored: return .upMirrored
        case .down: return .down
        case .downMirrored: return .downMirrored
        case .left: return .left
        case .leftMirrored: return .leftMirrored
        case .right: return .right
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
