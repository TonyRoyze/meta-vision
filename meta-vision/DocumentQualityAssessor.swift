import CoreImage
import CoreImage.CIFilterBuiltins
import CoreGraphics

struct DocumentQualityAssessor {
    private let context = CIContext(options: [.cacheIntermediates: false])

    func assess(_ image: CGImage) throws -> DocumentQuality {
        guard image.width >= 600, image.height >= 600 else {
            throw DocumentQualityError.tooSmall
        }

        let input = CIImage(cgImage: image)
        let filter = CIFilter.areaAverage()
        filter.inputImage = input
        filter.extent = input.extent

        guard let output = filter.outputImage else {
            return .good
        }

        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(
            output,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        let luminance = (0.2126 * Double(pixel[0])
                         + 0.7152 * Double(pixel[1])
                         + 0.0722 * Double(pixel[2])) / 255

        if luminance < 0.06 { throw DocumentQualityError.tooDark }
        if luminance > 0.995 { throw DocumentQualityError.overexposed }
        return .good
    }
}

enum DocumentQuality: Equatable {
    case good
}

enum DocumentQualityError: LocalizedError {
    case tooSmall
    case tooDark
    case overexposed

    var errorDescription: String? {
        switch self {
        case .tooSmall:
            "The image is too small to describe reliably. Move closer and try again."
        case .tooDark:
            "The scene is almost completely dark. Add more light and try again."
        case .overexposed:
            "The image is washed out by bright light. Reduce glare and try again."
        }
    }
}
