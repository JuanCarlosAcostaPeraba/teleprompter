import AppKit
import ScriptTracking
import SwiftUI

@MainActor
final class Prompter: ObservableObject {
    @Published private(set) var script = Script("")
    @Published private(set) var cursor = 0
    @Published private(set) var listening = false
    @Published private(set) var starting = false
    @Published private(set) var error: String?
    @Published var showTranscript = false
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

    var readerIsVisible: Bool { panel?.isVisible == true }

    func raiseReader() {
        panel?.makeKeyAndOrderFront(nil)
    }
    private let speech = SpeechInput()
    private var panel: NSPanel?
    private var previous = ""

    func show(text: String) {
        pause()
        script = Script(text)
        guard !script.words.isEmpty else { return }
        cursor = 0
        error = nil
        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 660, height: 320),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered, defer: false
            )
            panel.title = "Lector · Teleprompter"
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isMovableByWindowBackground = true
            panel.setFrameAutosaveName("Teleprompter Reader")
            panel.minSize = NSSize(width: 400, height: 220)
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
            self.panel = panel
        }
        panel?.sharingType = limitCapture ? .none : .readOnly
        panel?.makeKeyAndOrderFront(nil)
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
            }) { [weak self] text, reset in
                guard let self else { return }
                if reset {
                    previous = ""
                    starting = false
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

struct Reader: View {
    @ObservedObject var model: Prompter
    private let ink = Color(red: 0.06, green: 0.09, blue: 0.15)
    private let highlight = Color(red: 0.53, green: 0.81, blue: 1)

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
            HStack(spacing: 12) {
                Button {
                    model.toggleVoice()
                } label: {
                    Label(model.listening || model.starting ? "Pausar" : "Escuchar",
                          systemImage: model.listening ? "pause.fill" : "mic.fill")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.space, modifiers: [])
                Button("Volver al inicio", systemImage: "backward.end") { model.seek(0) }
                    .labelStyle(.iconOnly)
                Button("Retroceder", systemImage: "chevron.left") { model.seek(model.cursor - 8) }
                    .labelStyle(.iconOnly)
                Button("Avanzar", systemImage: "chevron.right") { model.seek(model.cursor + 8) }
                    .labelStyle(.iconOnly)
                Spacer()
                Menu("Vista", systemImage: "textformat.size") {
                    Toggle("Mostrar transcripción", isOn: $model.showTranscript)
                    Button("Aumentar texto") { model.fontSize = min(72, model.fontSize + 4) }
                    Button("Reducir texto") { model.fontSize = max(18, model.fontSize - 4) }
                    Button("Aumentar opacidad") { model.opacity = min(1, model.opacity + 0.1) }
                    Button("Reducir opacidad") { model.opacity = max(0.5, model.opacity - 0.1) }
                }.fixedSize()
            }
            .padding(12)
            if let error = model.error {
                Text(error).font(.callout).foregroundStyle(.yellow).padding(.horizontal, 18)
            }
            Divider()
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
            if model.showTranscript && !model.transcript.isEmpty {
                Text(model.transcript).font(.caption).lineLimit(2).truncationMode(.head)
                    .foregroundStyle(.secondary).padding(.horizontal, 14)
            }
            HStack {
                Text(model.starting ? "Activando micrófono…" : model.listening ? "Siguiendo tu voz" : "Modo manual")
                Spacer()
                Text("\(model.cursor) / \(model.script.words.count)").monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14).padding(.vertical, 8)
        }
        .background(ink.opacity(model.opacity))
        .preferredColorScheme(.dark)
        .tint(.blue)
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

private extension String {
    var isNewlineOnly: Bool { self == "\n" || self == "\r\n" }
}
