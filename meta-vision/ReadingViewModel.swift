import Combine
import SwiftUI
import UIKit

@MainActor
final class ReadingViewModel: ObservableObject {
    @Published private(set) var status: ReadingStatus = .ready(deviceName: "iPhone camera")
    @Published private(set) var recognizedText = ""
    @Published var isShowingError = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var history: [ReadingRecord]
    @Published var speechRate: Double {
        didSet { UserDefaults.standard.set(speechRate, forKey: "speechRate") }
    }
    @Published private(set) var isGemmaConfigured = false

    private let recognizer: VisionTextRecognizer
    private let qualityAssessor: DocumentQualityAssessor
    private let gemmaVerifier: GemmaVerifier
    private let speechReader: SpeechReader
    private let historyStore: ReadingHistoryStore
    private var readTask: Task<Void, Never>?

    init(
        recognizer: VisionTextRecognizer? = nil,
        qualityAssessor: DocumentQualityAssessor? = nil,
        gemmaVerifier: GemmaVerifier? = nil,
        speechReader: SpeechReader? = nil,
        historyStore: ReadingHistoryStore? = nil
    ) {
        let resolvedSpeechReader = speechReader ?? SpeechReader()
        self.recognizer = recognizer ?? VisionTextRecognizer()
        self.qualityAssessor = qualityAssessor ?? DocumentQualityAssessor()
        let resolvedGemmaVerifier = gemmaVerifier ?? GemmaVerifier()
        self.gemmaVerifier = resolvedGemmaVerifier
        self.speechReader = resolvedSpeechReader
        let resolvedHistoryStore = historyStore ?? ReadingHistoryStore()
        self.historyStore = resolvedHistoryStore
        self.history = resolvedHistoryStore.load()
        let storedRate = UserDefaults.standard.double(forKey: "speechRate")
        self.speechRate = storedRate == 0 ? 0.45 : storedRate
        resolvedSpeechReader.didFinish = { [weak self] in
            guard let self, self.status == .speaking else { return }
            self.status = .ready(deviceName: "iPhone camera")
        }
        Task { [weak self] in
            self?.isGemmaConfigured = await resolvedGemmaVerifier.isConfigured
        }
    }

    var canRead: Bool {
        if case .ready = status { return true }
        return false
    }

    func clearError() {
        status = .ready(deviceName: "iPhone camera")
    }

    func reportCameraUnavailable() {
        show(CameraError.unavailable)
    }

    func reportCameraError(_ error: Error) {
        show(error)
    }

    func processCapturedImage(_ image: UIImage) {
        guard canRead else { return }
        guard let cgImage = image.normalizedCGImage else {
            show(CaptureError.imageCreationFailed)
            return
        }
        guard let imageData = cgImage.gemmaJPEGData(maxDimension: 1_280) else {
            show(CaptureError.imageCreationFailed)
            return
        }
        readTask?.cancel()
        readTask = Task {
            do {
                status = .checkingQuality
                _ = try qualityAssessor.assess(cgImage)
                try Task.checkCancellation()

                status = .recognizing
                let ocrText: String?
                do {
                    ocrText = try await recognizer.recognizeText(in: cgImage)
                } catch RecognitionError.noTextFound {
                    ocrText = nil
                }
                try Task.checkCancellation()

                status = .describing
                let text = try await gemmaVerifier.describe(imageData: imageData, ocrText: ocrText)
                try Task.checkCancellation()

                recognizedText = text
                history = historyStore.add(text: text, to: history)
                status = .speaking
                try speechReader.speak(text, rate: Float(speechRate))
            } catch is CancellationError {
                status = .ready(deviceName: "iPhone camera")
            } catch {
                show(error)
            }
        }
    }

    func installGemmaModel(from url: URL) async {
        do {
            try await gemmaVerifier.installModel(from: url)
            isGemmaConfigured = true
        } catch {
            show(error)
        }
    }

    func installDownloadedGemmaModel(from url: URL) async {
        do {
            try await gemmaVerifier.installDownloadedModel(from: url)
            isGemmaConfigured = true
        } catch {
            show(error)
        }
    }

    func reportModelDownloadError(_ error: Error) {
        show(error)
    }

    func repeatText() {
        guard !recognizedText.isEmpty else { return }
        do {
            status = .speaking
            try speechReader.speak(recognizedText, rate: Float(speechRate))
        } catch {
            show(error)
        }
    }

    func summarize() {
        guard !recognizedText.isEmpty else { return }
        readTask?.cancel()
        readTask = Task {
            do {
                status = .summarizing
                let summary = try await gemmaVerifier.summarize(recognizedText)
                try Task.checkCancellation()
                status = .speaking
                try speechReader.speak("Summary. \(summary)", rate: Float(speechRate))
            } catch is CancellationError {
                status = .ready(deviceName: "iPhone camera")
            } catch {
                show(error)
            }
        }
    }

    func previewVoice() {
        do {
            try speechReader.speak(
                "This is how Meta Vision will describe the world aloud.",
                rate: Float(speechRate)
            )
        } catch {
            show(error)
        }
    }

    func open(_ record: ReadingRecord) {
        recognizedText = record.text
        do {
            status = .speaking
            try speechReader.speak(record.text, rate: Float(speechRate))
        } catch {
            show(error)
        }
    }

    func deleteHistory(at offsets: IndexSet) {
        history = historyStore.delete(at: offsets, from: history)
    }

    func stopSpeaking() {
        readTask?.cancel()
        speechReader.stop()
        status = .ready(deviceName: "iPhone camera")
    }

    private func show(_ error: Error) {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        isShowingError = true
        status = .ready(deviceName: "iPhone camera")
    }
}

private extension UIImage {
    var normalizedCGImage: CGImage? {
        if imageOrientation == .up, let cgImage { return cgImage }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let normalized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
        return normalized.cgImage
    }
}

private extension CGImage {
    func gemmaJPEGData(maxDimension: CGFloat) -> Data? {
        let longestEdge = CGFloat(max(width, height))
        let scale = min(1, maxDimension / longestEdge)
        let outputSize = CGSize(
            width: max(1, (CGFloat(width) * scale).rounded()),
            height: max(1, (CGFloat(height) * scale).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: outputSize, format: format).image { _ in
            UIImage(cgImage: self).draw(in: CGRect(origin: .zero, size: outputSize))
        }
        return resized.jpegData(compressionQuality: 0.85)
    }
}

enum CameraError: LocalizedError {
    case unavailable
    case permissionDenied
    case configurationFailed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "The camera is unavailable. Run Meta Vision on an iPhone and allow camera access in Settings."
        case .permissionDenied:
            "Camera access is off. Allow Meta Vision to use the camera in Settings, then try again."
        case .configurationFailed:
            "The camera could not start. Close other camera apps and try again."
        }
    }
}

enum ReadingStatus: Equatable {
    case connecting
    case connectionFailed
    case ready(deviceName: String)
    case capturing
    case checkingQuality
    case recognizing
    case describing
    case summarizing
    case speaking

    var title: String {
        switch self {
        case .connecting: "Connecting to glasses"
        case .connectionFailed: "Glasses unavailable"
        case .ready: "Camera ready"
        case .capturing: "Taking a picture"
        case .checkingQuality: "Checking image quality"
        case .recognizing: "Checking visible text"
        case .describing: "Understanding the scene"
        case .summarizing: "Summarizing with Gemma"
        case .speaking: "Speaking"
        }
    }

    var detail: String {
        switch self {
        case .connecting: "Looking for your glasses…"
        case .connectionFailed: "Check the connection and try again."
        case .ready(let deviceName): deviceName
        case .capturing: "Hold still for a moment."
        case .checkingQuality: "Checking lighting and image size."
        case .recognizing: "Looking for useful signs, labels, and document text."
        case .describing: "Gemma is describing people, objects, actions, and surroundings."
        case .summarizing: "Creating a concise on-device summary."
        case .speaking: "Speaking the description through the selected audio output."
        }
    }

    var actionTitle: String {
        switch self {
        case .capturing: "Capturing…"
        case .checkingQuality: "Checking quality…"
        case .recognizing: "Recognizing…"
        case .describing: "Describing…"
        case .summarizing: "Summarizing…"
        case .speaking: "Speaking…"
        case .connectionFailed: "Try again"
        default: "Please wait…"
        }
    }

    var symbolName: String {
        switch self {
        case .connecting: "eyeglasses"
        case .connectionFailed: "exclamationmark.triangle.fill"
        case .ready: "checkmark.circle.fill"
        case .capturing: "camera.fill"
        case .checkingQuality: "sun.max.fill"
        case .recognizing: "text.viewfinder"
        case .describing: "sparkles"
        case .summarizing: "text.quote"
        case .speaking: "speaker.wave.2.fill"
        }
    }

    var tint: Color {
        switch self {
        case .ready: .green
        case .connectionFailed: .red
        case .connecting, .capturing, .checkingQuality, .recognizing, .describing, .summarizing, .speaking: .accentColor
        }
    }

    var isBusy: Bool {
        switch self {
        case .capturing, .checkingQuality, .recognizing, .describing, .summarizing, .speaking: true
        case .connecting, .connectionFailed, .ready: false
        }
    }
}
