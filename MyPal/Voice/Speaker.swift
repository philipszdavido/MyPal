import AVFoundation
import Observation

/// Reads replies aloud with the system voice. One message speaks at a time.
@MainActor
@Observable
final class Speaker: NSObject {

    static let shared = Speaker()

    /// The message currently being read, if any.
    private(set) var speakingId: UUID?

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func toggle(_ message: ChatMessage) {
        if speakingId == message.id {
            stop()
        } else {
            speak(message)
        }
    }

    func speak(_ message: ChatMessage) {
        Dictation.shared.stop()
        synthesizer.stopSpeaking(at: .immediate)

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            Log.chat.error("Audio session for speech failed: \(error.localizedDescription)")
        }

        let utterance = AVSpeechUtterance(string: message.text.markdownStripped)
        utterance.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        speakingId = message.id
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        speakingId = nil
    }

    private func didStop() {
        guard !synthesizer.isSpeaking else { return }
        speakingId = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

extension Speaker: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.didStop() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.didStop() }
    }
}
