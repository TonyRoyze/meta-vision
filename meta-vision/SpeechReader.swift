import AVFoundation

@MainActor
final class SpeechReader: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    var didFinish: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, rate: Float) throws {
        synthesizer.stopSpeaking(at: .immediate)
        try activateAudioSession()

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = max(AVSpeechUtteranceMinimumSpeechRate,
                             min(rate, AVSpeechUtteranceMaximumSpeechRate))
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.language.languageCode?.identifier)
        utterance.volume = 1
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        deactivateAudioSession()
    }

    private func activateAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        do {
            do {
                try session.setCategory(
                    .playback,
                    mode: .spokenAudio,
                    options: [.duckOthers]
                )
            } catch {
                // Some routes reject optional spoken-audio behavior. Basic playback
                // still bypasses the silent switch and supports A2DP automatically.
                try session.setCategory(.playback, mode: .default, options: [])
            }
            try session.setActive(true)
        } catch {
            throw SpeechError.audioSessionFailed(error.localizedDescription)
        }
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            self?.deactivateAudioSession()
            self?.didFinish?()
        }
    }
}

enum SpeechError: LocalizedError {
    case audioSessionFailed(String)

    var errorDescription: String? {
        switch self {
        case .audioSessionFailed(let detail):
            "Meta Vision could not start spoken audio. Check the volume and audio output, then try again. \(detail)"
        }
    }
}
