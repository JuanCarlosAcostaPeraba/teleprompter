import AVFoundation
import CoreAudio
import Speech

@MainActor
final class SpeechInput {
    private var engine = AVAudioEngine()
    private var configurationObserver: NSObjectProtocol?
    private var defaultInputObserver: AudioObjectPropertyListenerBlock?
    private var reconnect: Task<Void, Never>?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var renewal: Task<Void, Never>?
    private var hasTap = false
    private var generation = UUID()

    func start(
        locale: String,
        context: @escaping () -> [String],
        onLevel: @escaping (Double) -> Void,
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
        listen(recognizer, context: context, onLevel: onLevel, onText: onText, onError: onError)
    }

    private func listen(
        _ recognizer: SFSpeechRecognizer,
        context: @escaping () -> [String],
        onLevel: @escaping (Double) -> Void,
        onText: @escaping (String, Bool) -> Void,
        onError: @escaping (String) -> Void
    ) {
        stop()
        engine = AVAudioEngine()
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
        let meterInterval = max(1, AVAudioFramePosition(format.sampleRate / 20))
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            request.append(buffer)
            let end = time.sampleTime + AVAudioFramePosition(buffer.frameLength)
            guard time.sampleTime / meterInterval != end / meterInterval else { return }
            let level = Self.meterLevel(buffer)
            Task { @MainActor in
                guard self?.generation == current else { return }
                onLevel(level)
            }
        }
        hasTap = true
        do {
            try engine.start()
        } catch {
            stop()
            onError("No se pudo iniciar el micrófono. \(error.localizedDescription)")
            return
        }

        let audioChanged: @Sendable () -> Void = { [weak self] in
            Task { @MainActor in
                guard let self, self.generation == current else { return }
                self.reconnect?.cancel()
                self.reconnect = Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(250))
                    guard !Task.isCancelled, let self, self.generation == current else { return }
                    onLevel(0)
                    self.listen(recognizer, context: context, onLevel: onLevel, onText: onText, onError: onError)
                }
            }
        }
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil
        ) { _ in audioChanged() }

        let inputObserver: AudioObjectPropertyListenerBlock = { _, _ in audioChanged() }
        var address = Self.defaultInputAddress
        if AudioObjectAddPropertyListenerBlock(Self.audioSystem, &address, .main, inputObserver) == noErr {
            defaultInputObserver = inputObserver
        }

        onText("", true)
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let transcript = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal == true
            let failure = error.map { $0 as NSError }
            Task { @MainActor in
                guard let self, self.generation == current else { return }
                if let transcript { onText(transcript, false) }
                guard self.reconnect == nil else { return }
                if isFinal || (failure?.domain == "kAFAssistantErrorDomain" && failure?.code == 1110) {
                    self.listen(recognizer, context: context, onLevel: onLevel, onText: onText, onError: onError)
                } else if let failure {
                    self.stop()
                    onError("Se interrumpió el reconocimiento. \(failure.localizedDescription)")
                }
            }
        }
        renewal = Task { [weak self] in
            try? await Task.sleep(for: .seconds(50))
            guard !Task.isCancelled, let self, self.generation == current else { return }
            self.listen(recognizer, context: context, onLevel: onLevel, onText: onText, onError: onError)
        }
    }

    var inputName: String? {
        if let unit = engine.inputNode.audioUnit {
            var device = AudioDeviceID(kAudioObjectUnknown)
            var size = UInt32(MemoryLayout<AudioDeviceID>.size)
            if AudioUnitGetProperty(unit, kAudioOutputUnitProperty_CurrentDevice,
                                    kAudioUnitScope_Global, 0, &device, &size) == noErr,
               let name = deviceName(device), !name.hasPrefix("CADefaultDeviceAggregate-") {
                return name
            }
        }

        // AVAudioEngine can wrap the default input and output in a private aggregate.
        var property = Self.defaultInputAddress
        var device = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(Self.audioSystem, &property,
                                         0, nil, &size, &device) == noErr else { return nil }
        return deviceName(device)
    }

    private static let audioSystem = AudioObjectID(kAudioObjectSystemObject)
    private static var defaultInputAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private func deviceName(_ device: AudioDeviceID) -> String? {
        guard device != kAudioObjectUnknown else { return nil }
        var property = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout.size(ofValue: name))
        guard AudioObjectGetPropertyData(device, &property, 0, nil, &size, &name) == noErr else { return nil }
        return name?.takeRetainedValue() as String?
    }

    private nonisolated static func meterLevel(_ buffer: AVAudioPCMBuffer) -> Double {
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return 0 }
        let frames = Int(buffer.frameLength)
        let count = Int(buffer.format.channelCount)
        var energy = 0.0
        for channel in 0..<count {
            for index in 0..<frames {
                let sample = Double(channels[channel][index * buffer.stride])
                energy += sample * sample
            }
        }
        let decibels = 10 * log10(max(energy / Double(count * frames), 0.000001))
        return min(1, max(0, (decibels + 60) / 60))
    }

    func stop() {
        generation = UUID()
        renewal?.cancel()
        renewal = nil
        reconnect?.cancel()
        reconnect = nil
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
            self.configurationObserver = nil
        }
        if let defaultInputObserver {
            var address = Self.defaultInputAddress
            AudioObjectRemovePropertyListenerBlock(Self.audioSystem, &address, .main, defaultInputObserver)
            self.defaultInputObserver = nil
        }
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
