import AVFoundation
import Observation
import Speech

/// Speech-to-text for the composer. Recognition stays on device whenever the locale supports it.
@MainActor
@Observable
final class Dictation {

    static let shared = Dictation()

    private(set) var isRecording = false
    private(set) var errorMessage: String?

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private let recognizer = SFSpeechRecognizer()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?

    /// Starts listening. `onText` receives the full transcript so far, each time it changes.
    func start(onText: @escaping @MainActor (String) -> Void) async {
        guard !isRecording else { return }
        errorMessage = nil

        guard await Self.requestSpeechPermission(), await Self.requestMicrophonePermission() else {
            errorMessage = "Allow microphone and speech recognition access in Settings to dictate."
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Dictation isn't available right now."
            return
        }

        Speaker.shared.stop()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.addsPunctuation = true
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }

            let input = engine.inputNode
            Self.installTap(on: input, feeding: request)
            engine.prepare()
            try engine.start()

            self.request = request
            isRecording = true
            task = recognizer.recognitionTask(with: request, resultHandler: Self.resultHandler { [weak self] text, isDone in
                // Late results after stop() (e.g. once the message was sent) must not refill the composer.
                guard let self, self.isRecording else { return }
                if let text { onText(text) }
                if isDone { self.stop() }
            })
        } catch {
            Log.chat.error("Dictation failed to start: \(error.localizedDescription)")
            errorMessage = "Couldn't start dictation."
            stop()
        }
    }

    func stop() {
        guard isRecording || engine.isRunning else { return }
        isRecording = false
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func clearError() { errorMessage = nil }

    // These run on audio / speech queues, so they must not inherit main-actor isolation.

    private nonisolated static func installTap(on input: AVAudioInputNode, feeding request: SFSpeechAudioBufferRecognitionRequest) {
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
    }

    private nonisolated static func resultHandler(
        _ deliver: @escaping @MainActor (String?, Bool) -> Void
    ) -> @Sendable (SFSpeechRecognitionResult?, Error?) -> Void {
        { result, error in
            let text = result?.bestTranscription.formattedString
            let isDone = error != nil || (result?.isFinal ?? false)
            Task { @MainActor in deliver(text, isDone) }
        }
    }

    private nonisolated static func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private nonisolated static func requestMicrophonePermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }
}
