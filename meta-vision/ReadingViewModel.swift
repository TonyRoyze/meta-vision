import Combine
import SwiftUI

@MainActor
final class ReadingViewModel: ObservableObject {
    @Published private(set) var status: ReadingStatus = .connecting
    @Published private(set) var recognizedText = ""
    @Published var isShowingError = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var history: [ReadingRecord]
    @Published var speechRate: Double {
        didSet { UserDefaults.standard.set(speechRate, forKey: "speechRate") }
    }

    private let glasses: any GlassesCaptureProviding
    private let recognizer: VisionTextRecognizer
    private let qualityAssessor: DocumentQualityAssessor
    private let speechReader: SpeechReader
    private let historyStore: ReadingHistoryStore
    private var readTask: Task<Void, Never>?

    init(
        glasses: (any GlassesCaptureProviding)? = nil,
        recognizer: VisionTextRecognizer? = nil,
        qualityAssessor: DocumentQualityAssessor? = nil,
        speechReader: SpeechReader? = nil,
        historyStore: ReadingHistoryStore? = nil
    ) {
        let resolvedGlasses = glasses ?? MockGlassesCaptureProvider()
        let resolvedSpeechReader = speechReader ?? SpeechReader()
        self.glasses = resolvedGlasses
        self.recognizer = recognizer ?? VisionTextRecognizer()
        self.qualityAssessor = qualityAssessor ?? DocumentQualityAssessor()
        self.speechReader = resolvedSpeechReader
        let resolvedHistoryStore = historyStore ?? ReadingHistoryStore()
        self.historyStore = resolvedHistoryStore
        self.history = resolvedHistoryStore.load()
        let storedRate = UserDefaults.standard.double(forKey: "speechRate")
        self.speechRate = storedRate == 0 ? 0.45 : storedRate
        resolvedSpeechReader.didFinish = { [weak self] in
            guard let self, self.status == .speaking else { return }
            self.status = .ready(deviceName: resolvedGlasses.deviceName)
        }
    }

    var canRead: Bool {
        if case .ready = status { return true }
        return false
    }

    func connect() async {
        guard status == .connecting else { return }
        do {
            try await glasses.connect()
            status = .ready(deviceName: glasses.deviceName)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            isShowingError = true
            status = .connectionFailed
        }
    }

    func retry() {
        if status == .connectionFailed {
            status = .connecting
            Task { await connect() }
        } else {
            readDocument()
        }
    }

    func readDocument() {
        guard canRead else { return }
        readTask?.cancel()
        readTask = Task {
            do {
                status = .capturing
                let image = try await glasses.captureDocument()
                try Task.checkCancellation()

                status = .checkingQuality
                _ = try qualityAssessor.assess(image)
                try Task.checkCancellation()

                status = .recognizing
                let text = try await recognizer.recognizeText(in: image)
                try Task.checkCancellation()

                recognizedText = text
                history = historyStore.add(text: text, to: history)
                status = .speaking
                speechReader.speak(text, rate: Float(speechRate))
            } catch is CancellationError {
                status = .ready(deviceName: glasses.deviceName)
            } catch {
                show(error)
            }
        }
    }

    func repeatText() {
        guard !recognizedText.isEmpty else { return }
        status = .speaking
        speechReader.speak(recognizedText, rate: Float(speechRate))
    }

    func summarize() {
        guard !recognizedText.isEmpty else { return }
        let summary = recognizedText
            .split(whereSeparator: { ".!?".contains($0) })
            .prefix(2)
            .joined(separator: ". ")
        status = .speaking
        speechReader.speak("Summary. \(summary).", rate: Float(speechRate))
    }

    func previewVoice() {
        speechReader.speak("This is how Meta Vision will read documents aloud.",
                           rate: Float(speechRate))
    }

    func open(_ record: ReadingRecord) {
        recognizedText = record.text
        status = .speaking
        speechReader.speak(record.text, rate: Float(speechRate))
    }

    func deleteHistory(at offsets: IndexSet) {
        history = historyStore.delete(at: offsets, from: history)
    }

    func stopSpeaking() {
        readTask?.cancel()
        speechReader.stop()
        status = .ready(deviceName: glasses.deviceName)
    }

    private func show(_ error: Error) {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        isShowingError = true
        status = .ready(deviceName: glasses.deviceName)
    }
}

enum ReadingStatus: Equatable {
    case connecting
    case connectionFailed
    case ready(deviceName: String)
    case capturing
    case checkingQuality
    case recognizing
    case speaking

    var title: String {
        switch self {
        case .connecting: "Connecting to glasses"
        case .connectionFailed: "Glasses unavailable"
        case .ready: "Glasses connected"
        case .capturing: "Taking a picture"
        case .checkingQuality: "Checking image quality"
        case .recognizing: "Reading the document"
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
        case .recognizing: "Finding and checking text on device."
        case .speaking: "Reading through the selected audio output."
        }
    }

    var actionTitle: String {
        switch self {
        case .capturing: "Capturing…"
        case .checkingQuality: "Checking quality…"
        case .recognizing: "Recognizing…"
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
        case .speaking: "speaker.wave.2.fill"
        }
    }

    var tint: Color {
        switch self {
        case .ready: .green
        case .connectionFailed: .red
        case .connecting, .capturing, .checkingQuality, .recognizing, .speaking: .accentColor
        }
    }

    var isBusy: Bool {
        switch self {
        case .capturing, .checkingQuality, .recognizing, .speaking: true
        case .connecting, .connectionFailed, .ready: false
        }
    }
}
