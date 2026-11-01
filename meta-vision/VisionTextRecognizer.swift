import CoreGraphics
import Vision

struct VisionTextRecognizer {
    func recognizeText(in image: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true

                do {
                    try VNImageRequestHandler(cgImage: image).perform([request])
                    let lines = (request.results ?? [])
                        .compactMap { observation in
                            observation.topCandidates(1).first.map { (observation, $0) }
                        }
                        .sorted { lhs, rhs in
                            let verticalDifference = lhs.0.boundingBox.midY - rhs.0.boundingBox.midY
                            if abs(verticalDifference) > 0.02 {
                                return lhs.0.boundingBox.midY > rhs.0.boundingBox.midY
                            }
                            return lhs.0.boundingBox.minX < rhs.0.boundingBox.minX
                        }
                        .map(\.1.string)

                    let text = lines.joined(separator: "\n")
                    guard !text.isEmpty else {
                        throw RecognitionError.noTextFound
                    }
                    continuation.resume(returning: text)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

enum RecognitionError: LocalizedError {
    case noTextFound

    var errorDescription: String? {
        "No text was found. Hold the document steady, improve the lighting, and try again."
    }
}
