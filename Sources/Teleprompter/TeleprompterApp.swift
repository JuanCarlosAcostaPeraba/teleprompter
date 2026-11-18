import AppKit
import ScriptTracking
import SwiftUI

@MainActor
final class Prompter: ObservableObject {
    @Published private(set) var script = Script("")
    @Published private(set) var scriptID = UUID()
    @Published private(set) var cursor = 0
    @Published private(set) var listening = false
    @Published private(set) var starting = false
    @Published private(set) var error: String?
    @Published var showTranscript = false
    let microphone = MicrophoneSignal()
    @Published private(set) var microphoneName: String?
    @Published var listenOnOpen = UserDefaults.standard.object(forKey: "listenOnOpen") as? Bool ?? true {
        didSet { UserDefaults.standard.set(listenOnOpen, forKey: "listenOnOpen") }
    }
    @Published var blurBackground = UserDefaults.standard.object(forKey: "blurBackground") as? Bool ?? true {
        didSet { UserDefaults.standard.set(blurBackground, forKey: "blurBackground") }
    }
    @Published private var highlightRGB: [Double] = {
        guard let saved = UserDefaults.standard.array(forKey: "highlightRGB") as? [Double],
              saved.count == 3, saved.allSatisfy({ (0...1).contains($0) }) else {
            return [0.53, 0.95, 0.83]
        }
        return saved
    }()

    var highlightColor: Color {
        get { Color(red: highlightRGB[0], green: highlightRGB[1], blue: highlightRGB[2]) }
        set {
            guard let rgb = NSColor(newValue).usingColorSpace(.sRGB) else { return }
            highlightRGB = [rgb.redComponent, rgb.greenComponent, rgb.blueComponent]
            UserDefaults.standard.set(highlightRGB, forKey: "highlightRGB")
        }
    }
    @Published private(set) var transcript = ""
    @Published var fontSize = UserDefaults.standard.object(forKey: "fontSize") as? Double ?? 32 {
        didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") }
    }
    @Published var opacity = UserDefaults.standard.object(forKey: "opacity") as? Double ?? 0.96 {
        didSet { UserDefaults.standard.set(opacity, forKey: "opacity") }
    }
    @Published var locale = UserDefaults.standard.string(forKey: "locale") ?? "es-ES" {
        didSet {
            UserDefaults.standard.set(locale, forKey: "locale")
            if oldValue != locale { pause() }
        }
    }
    @Published var limitCapture = UserDefaults.standard.object(forKey: "limitCapture") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(limitCapture, forKey: "limitCapture")
            panel?.sharingType = limitCapture ? .none : .readOnly
        }
    }

    var editScript: () -> Void = {}

    var readerIsVisible: Bool { panel?.isVisible == true }

    func raiseReader() {
        panel?.makeKeyAndOrderFront(nil)
    }
    private let speech = SpeechInput()
    private var panel: NSPanel?
    private var previous = ""

    func closeReader() {
        panel?.close()
    }

    @discardableResult
    func show(text: String) -> Bool {
        let newScript = Script(text)
        guard !newScript.words.isEmpty else { return false }
        pause()
        script = newScript
        scriptID = UUID()
        cursor = 0
        error = nil
        if panel == nil {
            let panel = ReaderPanel(
                contentRect: NSRect(x: 0, y: 0, width: 660, height: 320),
                styleMask: [.borderless, .resizable],
                backing: .buffered, defer: false
            )
            panel.title = "Lector · Teleprompter"
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isMovableByWindowBackground = true

            panel.minSize = NSSize(width: 460, height: 200)
            panel.isReleasedWhenClosed = false
            panel.hidesOnDeactivate = false
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentView = NSHostingView(rootView: Reader(model: self))
            if let screen = NSScreen.main {
                let bounds = screen.visibleFrame
                panel.setFrameTopLeftPoint(NSPoint(x: bounds.midX - 330, y: bounds.maxY - 12))
            }
            panel.setFrameAutosaveName("Teleprompter Reader")
            self.panel = panel
        }
        panel?.sharingType = limitCapture ? .none : .readOnly
        panel?.makeKeyAndOrderFront(nil)
        if listenOnOpen { toggleVoice() }
        return true
    }

    func toggleVoice() {
        if listening || starting {
            pause()
            return
        }
        error = nil
        starting = true
        transcript = ""
        previous = ""
        Task { [weak self] in
            guard let self, starting else { return }
            await speech.start(locale: locale, context: { [weak self] in
                guard let self else { return [] }
                return script.recognitionContext(near: cursor)
            }, onLevel: { [weak self] level in
                self?.microphone.level = level
            }) { [weak self] text, reset in
                guard let self else { return }
                if reset {
                    previous = ""
                    starting = false
                    microphoneName = speech.inputName
                    listening = true
                } else {
                    if showTranscript { transcript = text }
                    cursor = script.nextPosition(after: cursor, transcript: text, previous: previous)
                    previous = text
                }
            } onError: { [weak self] message in
                self?.pause()
                self?.error = message
            }
        }
    }

    func pause() {
        speech.stop()
        starting = false
        listening = false
        microphone.level = 0
        previous = ""
    }

    func seek(_ position: Int) {
        cursor = min(max(position, 0), script.words.count)
    }
}

struct Editor: View {
    @ObservedObject var model: Prompter
    @AppStorage("script") private var script = ""
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("Guion").font(.system(size: 29, weight: .semibold))
                Spacer()
                Picker("Voz", selection: $model.locale) {
                    Text("Español").tag("es-ES")
                    Text("English").tag("en-US")
                }.pickerStyle(.segmented).frame(width: 170)
                Button(action: openSettings) {
                    Image(systemName: "gearshape")
                }
                .help("Ajustes")
                .accessibilityLabel("Ajustes")
            }

            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $script)
                        .font(.system(size: 17))
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .accessibilityLabel("Guion")
                    if script.isEmpty {
                        Text("Escribe o pega tu texto aquí…")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16).padding(.top, 14)
                            .allowsHitTesting(false)
                    }
                }
                .background(.background, in: RoundedRectangle(cornerRadius: 12))
                .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary) }
            }

            HStack {
                Text("Usa [corchetes] para indicaciones que no leas.")
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button("Abrir lector", systemImage: "play.fill") {
                    model.show(text: script)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(!script.contains(where: { $0.isLetter || $0.isNumber }))
            }
        }
        .padding(24)
        .frame(minWidth: 480, minHeight: 320)
        .tint(Color(red: 0.22, green: 0.41, blue: 0.72))
    }
}

private final class ReaderPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

struct Reader: View {
    @ObservedObject var model: Prompter
    private let ink = Color(red: 0.06, green: 0.09, blue: 0.15)
    private var highlight: Color { model.highlightColor }

    private var blocks: [[Script.Token]] {
        var result: [[Script.Token]] = [[]]
        var words = 0
        for token in model.script.tokens {
            if token.text == "\n" || token.text == "\r\n" || (words >= 14 && token.wordIndex != nil) {
                result.append([])
                words = 0
                if token.text.isNewlineOnly { continue }
            }
            result[result.count - 1].append(token)
            if token.wordIndex != nil { words += 1 }
        }
        return result
    }

    var body: some View {
        let blocks = blocks
        VStack(spacing: 0) {
            HStack {
                Label("Teleprompter", systemImage: "text.alignleft")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(highlight)
                Spacer()
                Button("Cerrar lector", systemImage: "xmark", action: model.closeReader)
                    .labelStyle(.iconOnly).buttonStyle(.plain)
                    .keyboardShortcut("w", modifiers: .command)
            }
            .padding(.horizontal, 18).padding(.top, 12)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(blocks.indices, id: \.self) { index in
                            Text(styled(blocks[index]))
                                .font(.system(size: model.fontSize, weight: .medium))
                                .lineSpacing(5)
                                .frame(minHeight: model.fontSize / 2, alignment: .leading)
                                .id(index)
                        }
                        Color.clear.frame(height: 80).accessibilityHidden(true)
                    }
                    .padding(.horizontal, 24).padding(.top, 12)
                }
                .onChange(of: model.cursor) {
                    let position = min(model.cursor, model.script.words.count - 1)
                    if position == 0 {
                        withAnimation(.easeOut(duration: 0.22)) { proxy.scrollTo(0, anchor: .top) }
                    } else if let index = blocks.firstIndex(where: { $0.contains { $0.wordIndex == position } }) {
                        withAnimation(.easeOut(duration: 0.22)) { proxy.scrollTo(index, anchor: .top) }
                    }
                }
                .environment(\.openURL, OpenURLAction { url in
                    guard url.scheme == "teleprompter", let position = Int(url.host ?? "") else { return .discarded }
                    model.seek(position)
                    return .handled
                })
            }
            .clipped()
            .id(model.scriptID)
            if let error = model.error {
                Text(error).font(.caption).foregroundStyle(.yellow).padding(.horizontal, 18)
            }
            if model.showTranscript && !model.transcript.isEmpty {
                Text(model.transcript).font(.caption).lineLimit(2).truncationMode(.head)
                    .foregroundStyle(.secondary).padding(.horizontal, 18).padding(.bottom, 4)
            }
            Divider()
            HStack(spacing: 8) {
                Button {
                    model.toggleVoice()
                } label: {
                    Label(model.listening || model.starting ? "Pausar" : "Escuchar",
                          systemImage: model.listening || model.starting ? "pause.fill" : "mic.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(highlight.opacity(0.75))
                .foregroundStyle(ink)
                .keyboardShortcut(.space, modifiers: [])
                MicrophoneMeter(signal: model.microphone, active: model.listening)
                Text(model.microphoneName ?? "Entrada de audio")
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.tail)
                    .help(model.microphoneName ?? "La entrada se identifica al activar la escucha")
                    .accessibilityLabel("Entrada de audio: \(model.microphoneName ?? "sin identificar")")
                Button("Reiniciar", systemImage: "arrow.counterclockwise") { model.seek(0) }
                    .labelStyle(.iconOnly)
                Button("Retroceder", systemImage: "chevron.left") { model.seek(model.cursor - 8) }
                    .labelStyle(.iconOnly)
                Button("Avanzar", systemImage: "chevron.right") { model.seek(model.cursor + 8) }
                    .labelStyle(.iconOnly)
                Button("Editar guion", systemImage: "square.and.pencil", action: model.editScript)
                    .labelStyle(.iconOnly)
                Menu("Vista", systemImage: "slider.horizontal.3") {
                    Toggle("Mostrar transcripción", isOn: $model.showTranscript)
                    Toggle("Solicitar exclusión de captura", isOn: $model.limitCapture)
                    Button("Aumentar texto") { model.fontSize = min(72, model.fontSize + 4) }
                    Button("Reducir texto") { model.fontSize = max(18, model.fontSize - 4) }
                    Button("Aumentar opacidad") { model.opacity = min(1, model.opacity + 0.1) }
                    Button("Reducir opacidad") { model.opacity = max(0.5, model.opacity - 0.1) }
                }
                .labelStyle(.iconOnly).fixedSize()
                Spacer(minLength: 0)
                Text("\(model.locale == "es-ES" ? "ES" : "EN")  ·  \(model.cursor)/\(model.script.words.count)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    .accessibilityLabel("\(model.listening ? "Siguiendo tu voz" : "Modo manual"), \(model.cursor) de \(model.script.words.count) palabras")
            }
            .controlSize(.small)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(ink.opacity(0.86))
        }
        .background {
            ZStack {
                if model.blurBackground {
                    Rectangle().fill(.ultraThinMaterial).opacity(model.opacity)
                }
                ink.opacity((model.blurBackground ? 0.68 : 1) * model.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 19))
        .overlay { RoundedRectangle(cornerRadius: 19).strokeBorder(.white.opacity(0.16)) }
        .preferredColorScheme(.dark)
        .onDisappear { model.pause() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            if let window = notification.object as? NSPanel, window.contentView is NSHostingView<Reader> {
                model.pause()
            }
        }
    }

    private func styled(_ tokens: [Script.Token]) -> AttributedString {
        var result = AttributedString()
        for token in tokens {
            var part = AttributedString(token.text)
            if let index = token.wordIndex {
                part.foregroundColor = index == model.cursor ? highlight : index < model.cursor ? .gray : .white
                part.link = URL(string: "teleprompter://\(index)")
                part.underlineStyle = .none
            } else {
                part.foregroundColor = token.text.hasPrefix("[") ? highlight.opacity(0.72) : .white
            }
            result += part
        }
        return result
    }
}

@MainActor
final class MicrophoneSignal: ObservableObject {
    @Published var level = 0.0
}

private struct MicrophoneMeter: View {
    @ObservedObject var signal: MicrophoneSignal
    let active: Bool

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<8) { index in
                Capsule()
                    .fill(active && signal.level > Double(index) / 8 ? (index >= 6 ? Color.yellow : Color.mint) : .white.opacity(0.18))
                    .frame(width: 3, height: CGFloat(6 + index * 2))
            }
        }
        .frame(height: 20)
        .help("Nivel del micrófono")
        .accessibilityLabel("Nivel del micrófono")
        .accessibilityValue(active ? "\(Int(signal.level * 100)) %" : "En pausa")
    }
}

private extension String {
    var isNewlineOnly: Bool { self == "\n" || self == "\r\n" }
}
