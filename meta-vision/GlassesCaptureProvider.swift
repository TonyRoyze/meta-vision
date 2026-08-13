import CoreGraphics
import UIKit

protocol GlassesCaptureProviding {
    var deviceName: String { get }

    func connect() async throws
    func captureDocument() async throws -> CGImage
}

/// Development provider that keeps the full capture and OCR flow runnable
/// without requiring physical Meta glasses.
struct MockGlassesCaptureProvider: GlassesCaptureProviding {
    let deviceName = "Demo Ray-Ban glasses"

    func connect() async throws {
        try await Task.sleep(for: .milliseconds(650))
    }

    @MainActor
    func captureDocument() async throws -> CGImage {
        try await Task.sleep(for: .milliseconds(500))

        let size = CGSize(width: 1200, height: 1600)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 14
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 54, weight: .regular),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraph,
            ]
            let text = "Community Library\n\nYour books are due Friday, August 21. Please return them at the front desk or renew them online.\n\nOpening hours: 9 AM to 6 PM."
            text.draw(
                in: CGRect(x: 90, y: 120, width: 1020, height: 1200),
                withAttributes: attributes
            )
        }

        guard let cgImage = image.cgImage else {
            throw CaptureError.imageCreationFailed
        }
        return cgImage
    }
}

enum CaptureError: LocalizedError {
    case imageCreationFailed

    var errorDescription: String? {
        "The glasses did not return a usable image."
    }
}
