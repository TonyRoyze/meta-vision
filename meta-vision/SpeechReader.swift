import AVFoundation

@MainActor
final class SpeechReader: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    var didFinish: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, rate: Float) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = max(AVSpeechUtteranceMinimumSpeechRate,
                             min(rate, AVSpeechUtteranceMaximumSpeechRate))
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.language.languageCode?.identifier)
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            self?.didFinish?()
        }
    }
}
