import AVFoundation
import Speech

@MainActor
final class SpeechInput {
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var renewal: Task<Void, Never>?
    private var hasTap = false
    private var generation = UUID()

    func start(
        locale: String,
        context: @escaping () -> [String],
        onText: @escaping (String, Bool) -> Void,
        onError: @escaping (String) -> Void
    ) async {
        stop()
        let current = generation
        let mic = await AVCaptureDevice.requestAccess(for: .audio)
        guard generation == current else { return }
        guard mic else {
            onError("Activa el micrófono para Teleprompter en Ajustes del Sistema.")
            return
        }
        let permission = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard generation == current else { return }
        guard permission == .authorized else {
            onError("Activa el reconocimiento de voz para Teleprompter en Ajustes del Sistema.")
            return
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)),
              recognizer.supportsOnDeviceRecognition, recognizer.isAvailable else {
            onError("El reconocimiento local no está disponible para este idioma. Puedes seguir en modo manual.")
            return
        }
        listen(recognizer, context: context, onText: onText, onError: onError)
    }

    private func listen(
        _ recognizer: SFSpeechRecognizer,
        context: @escaping () -> [String],
        onText: @escaping (String, Bool) -> Void,
        onError: @escaping (String) -> Void
    ) {
        stop()
        let current = generation
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.contextualStrings = context()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            onError("No se encontró una entrada de audio activa.")
            return
        }
        self.request = request
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        hasTap = true
        do {
            try engine.start()
        } catch {
            stop()
            onError("No se pudo iniciar el micrófono. \(error.localizedDescription)")
            return
        }

        onText("", true)
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let transcript = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal == true
            let failure = error.map { $0 as NSError }
            Task { @MainActor in
                guard let self, self.generation == current else { return }
                if let transcript { onText(transcript, false) }
                if isFinal || (failure?.domain == "kAFAssistantErrorDomain" && failure?.code == 1110) {
                    self.listen(recognizer, context: context, onText: onText, onError: onError)
                } else if let failure {
                    self.stop()
                    onError("Se interrumpió el reconocimiento. \(failure.localizedDescription)")
                }
            }
        }
        renewal = Task { [weak self] in
            try? await Task.sleep(for: .seconds(50))
            guard !Task.isCancelled, let self, self.generation == current else { return }
            self.listen(recognizer, context: context, onText: onText, onError: onError)
        }
    }

    func stop() {
        generation = UUID()
        renewal?.cancel()
        renewal = nil
        engine.stop()
        if hasTap {
            engine.inputNode.removeTap(onBus: 0)
            hasTap = false
        }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
    }
}
