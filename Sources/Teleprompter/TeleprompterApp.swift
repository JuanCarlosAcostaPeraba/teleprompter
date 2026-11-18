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
    @Published var useLiquidGlass = UserDefaults.standard.object(forKey: "useLiquidGlass") as? Bool ?? true {
        didSet { UserDefaults.standard.set(useLiquidGlass, forKey: "useLiquidGlass") }
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
    @Published var readerWidth = CameraPlacement.readerWidthRange.clamp(
        UserDefaults.standard.object(forKey: "readerWidth") as? Double ?? CameraPlacement.defaultReaderWidth
    ) {
        didSet {
            UserDefaults.standard.set(readerWidth, forKey: "readerWidth")
            if let panel, abs(panel.frame.width - readerWidth) > 0.5 {
                var frame = panel.frame
                frame.origin.x += (frame.width - readerWidth) / 2
                frame.size.width = readerWidth
                panel.setFrame(frame, display: true)
            }
        }
    }

    func restoreReaderLayout() {
        readerWidth = CameraPlacement.defaultReaderWidth
        guard let panel else {
            NSWindow.removeFrame(usingName: Self.readerFrameName)
            return
        }
        panel.centerUnderCamera()
    }

    func rememberReaderWidth(_ window: NSWindow) {
        guard window === panel, abs(window.frame.width - readerWidth) > 0.5 else { return }
        readerWidth = window.frame.width
    }

    @Published var fontSize = UserDefaults.standard.object(forKey: "fontSize") as? Double ?? 32 {
        didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") }
    }
    @Published var opacity = UserDefaults.standard.object(forKey: "opacity") as? Double ?? 0.96 {
        didSet { UserDefaults.standard.set(opacity, forKey: "opacity") }
    }
    @Published var locale = SpeechLanguage.initialSelection(UserDefaults.standard.string(forKey: "locale")) {
        didSet {
            UserDefaults.standard.set(locale, forKey: "locale")
            if oldValue != locale {
                pause()
                let offset = script.tokens.prefix { $0.wordIndex != cursor }.reduce(0) { $0 + $1.text.utf16.count }
                script = Script(script.tokens.map(\.text).joined(), locale: locale)
                scriptID = UUID()
                var position = 0
                cursor = script.tokens.prefix { token in
                    let startsBefore = position < offset
                    position += token.text.utf16.count
                    return startsBefore
                }.compactMap(\.wordIndex).count
            }
        }
    }
    @Published var limitCapture = UserDefaults.standard.object(forKey: "limitCapture") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(limitCapture, forKey: "limitCapture")
            panel?.sharingType = limitCapture ? .none : .readOnly
        }
    }

    var editScript: () -> Void = {}

    var visibleReaderFrame: NSRect? {
        guard let panel, panel.isVisible else { return nil }
        return panel.frame
    }

    var readerIsVisible: Bool { visibleReaderFrame != nil }

    func raiseReader() {
        panel?.makeKeyAndOrderFront(nil)
    }
    private static let readerFrameName = "Teleprompter Reader Layout"
    private let speech = SpeechInput()
    private var panel: ReaderPanel?
    private var previous = ""

    func closeReader() {
        panel?.close()
    }

    @discardableResult
    func show(text: String) -> Bool {
        let newScript = Script(text, locale: locale)
        guard !newScript.words.isEmpty else { return false }
        pause()
        script = newScript
        scriptID = UUID()
        cursor = 0
        error = nil
        if panel == nil {
            let panel = ReaderPanel(
                contentRect: NSRect(x: 0, y: 0, width: readerWidth, height: CameraPlacement.defaultReaderHeight),
                styleMask: [.borderless, .resizable],
                backing: .buffered, defer: false
            )
            panel.title = "Lector · Teleprompter"
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true

            panel.minSize = NSSize(width: CameraPlacement.readerWidthRange.lowerBound, height: 200)
            panel.maxSize.width = CameraPlacement.readerWidthRange.upperBound
            panel.isReleasedWhenClosed = false
            panel.hidesOnDeactivate = false
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentView = NSHostingView(rootView: Reader(model: self))
            let restored = panel.setFrameUsingName(Self.readerFrameName)
            panel.setFrameAutosaveName(Self.readerFrameName)
            let defaults = UserDefaults.standard
            if !defaults.bool(forKey: "compactReaderHeightInitialized") {
                if restored, abs(panel.frame.height - 320) < 0.5 {
                    var frame = panel.frame
                    frame.origin.y += frame.height - CameraPlacement.defaultReaderHeight
                    frame.size.height = CameraPlacement.defaultReaderHeight
                    panel.setFrame(frame, display: false)
                    panel.saveFrame(usingName: Self.readerFrameName)
                }
                defaults.set(true, forKey: "compactReaderHeightInitialized")
            }
            if !restored { panel.centerUnderCamera() }
            if abs(panel.frame.width - readerWidth) > 0.5 {
                var frame = panel.frame
                frame.origin.x += (frame.width - readerWidth) / 2
                frame.size.width = readerWidth
                panel.setFrame(frame, display: false)
            }
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
    let openReader: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("Guion").font(.system(size: 29, weight: .semibold))
                Spacer()
                SpeechLanguagePicker(title: "Voz", selection: $model.locale)
                    .frame(width: 220)
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
                    openReader(script)
                }
                .modifier(PrimaryGlassButton(enabled: model.useLiquidGlass))
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(!script.contains(where: { $0.isLetter || $0.isNumber }))
            }
        }
        .padding(24)
        .frame(minWidth: 480, minHeight: 320)
        .modifier(GlassControls(enabled: model.useLiquidGlass))
        .tint(Color(red: 0.22, green: 0.41, blue: 0.72))
    }
}

private final class ReaderPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    private var dragOffset: NSPoint?

    func centerUnderCamera() {
        guard let screen = CameraPlacement.screen else { return }
        setFrameTopLeftPoint(CameraPlacement.position(size: frame.size, on: screen))
        if !frameAutosaveName.isEmpty { saveFrame(usingName: frameAutosaveName) }
    }

    override func sendEvent(_ event: NSEvent) {
        let point = event.locationInWindow
        switch event.type {
        case .leftMouseDown:
            if (5...CameraPlacement.readerHeaderHeight).contains(frame.height - point.y), point.x > 10, point.x < frame.width - 10 {
                if event.clickCount == 2 {
                    dragOffset = nil
                    centerUnderCamera()
                } else {
                    dragOffset = point
                }
                return
            }
        case .leftMouseDragged:
            if let dragOffset {
                let pointer = convertPoint(toScreen: point)
                setFrameOrigin(NSPoint(x: pointer.x - dragOffset.x, y: pointer.y - dragOffset.y))
                return
            }
        case .leftMouseUp:
            if dragOffset != nil {
                dragOffset = nil
                return
            }
        default:
            break
        }
        super.sendEvent(event)
    }
}

struct Reader: View {
    @ObservedObject var model: Prompter
    var isPreview = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var audioNotice: String?
    private static let previewSpanish = Script("Así se verá el guion mientras lees. La línea activa se mantiene cerca de la cámara.", locale: "es-ES")
    private static let previewEnglish = Script("This is how your script will look as you read. The active line stays close to the camera.", locale: "en-US")
    private static let previewSpanishID = UUID()
    private static let previewEnglishID = UUID()

    private var spanish: Bool { Locale(identifier: model.locale).language.languageCode?.identifier == "es" }
    private var shownScript: Script {
        isPreview ? (spanish ? Self.previewSpanish : Self.previewEnglish) : model.script
    }
    private var shownScriptID: UUID {
        isPreview ? (spanish ? Self.previewSpanishID : Self.previewEnglishID) : model.scriptID
    }
    private var shownCursor: Int { isPreview ? 0 : model.cursor }
    private let ink = Color(red: 0.06, green: 0.09, blue: 0.15)
    private var highlight: Color { model.highlightColor }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: CameraPlacement.readerHeaderHeight)
                .contentShape(Rectangle())
                .help("Arrastra para mover el lector. Doble clic para centrarlo bajo la cámara.")
            GeometryReader { geometry in
                ReaderText(model: model, size: geometry.size, script: shownScript, scriptID: shownScriptID,
                           cursor: shownCursor, allowsSeeking: !isPreview)
            }
            .clipped()
            if !isPreview, let error = model.error {
                Text(error).font(.caption).foregroundStyle(.yellow).padding(.horizontal, 18)
            }
            if !isPreview, model.showTranscript && !model.transcript.isEmpty {
                Text(model.transcript).font(.caption).lineLimit(2).truncationMode(.head)
                    .foregroundStyle(.secondary).padding(.horizontal, 18).padding(.bottom, 4)
            }
            Divider()
            HStack(spacing: 8) {
                let active = model.listening || model.starting
                let audioName = model.microphoneName
                Button(action: model.toggleVoice) {
                    HStack(spacing: 4) {
                        Image(systemName: audioInputSymbol(for: audioName))
                        if active {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 8, weight: .semibold))
                        }
                    }
                }
                .accessibilityLabel(active ? "Pausar" : "Escuchar")
                .accessibilityValue(audioName ?? "Entrada sin identificar")
                .help((active ? "Pausar" : "Escuchar") + (audioName.map { " · " + $0 } ?? ""))
                .foregroundStyle(highlight)
                .keyboardShortcut(.space, modifiers: [])
                MicrophoneMeter(signal: model.microphone, active: model.listening)
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
                Text("\(model.locale)  ·  \(shownCursor)/\(shownScript.words.count)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(SpeechLanguage.name(model.locale))
                    .accessibilityLabel("\(model.listening ? "Siguiendo tu voz" : "Modo manual"), \(shownCursor) de \(shownScript.words.count) palabras")
                Button("Cerrar lector", systemImage: "xmark", action: model.closeReader)
                    .labelStyle(.iconOnly)
                    .help("Cerrar lector")
                    .keyboardShortcut("w", modifiers: .command)
            }
            .controlSize(.small)
            .modifier(GlassControls(enabled: model.useLiquidGlass))
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(ink.opacity(0.82))
        }
        .modifier(ReaderSurface(blur: model.blurBackground, opacity: model.opacity))
        .overlay(alignment: .topTrailing) {
            if let audioNotice, !isPreview {
                Label(audioNotice, systemImage: audioInputSymbol(for: audioNotice))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .modifier(AudioNoticeSurface(useLiquidGlass: model.useLiquidGlass, fallback: ink.opacity(0.94)))
                    .padding(8)
                    .allowsHitTesting(false)
                    .transition(reduceMotion ? .opacity : .offset(y: -8).combined(with: .opacity))
            }
        }
        .allowsHitTesting(!isPreview)
        .onChange(of: model.microphoneName) { _, name in
            guard !isPreview, let name else { return }
            withAnimation(.easeOut(duration: 0.16)) { audioNotice = name }
        }
        .task(id: audioNotice) {
            guard audioNotice != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.15)) { audioNotice = nil }
        }
        .onDisappear {
            if !isPreview { model.pause() }
            audioNotice = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResizeNotification)) { notification in
            if !isPreview, let window = notification.object as? NSWindow {
                model.rememberReaderWidth(window)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            if !isPreview, notification.object is ReaderPanel {
                model.pause()
            }
        }
    }

}

private func audioInputSymbol(for name: String?) -> String {
    guard let name else { return "mic" }
    if name.localizedCaseInsensitiveContains("AirPods") {
        if name.localizedCaseInsensitiveContains("Max") { return "airpodsmax" }
        if name.localizedCaseInsensitiveContains("Pro") { return "airpodspro" }
        return "airpods"
    }
    return name.localizedCaseInsensitiveContains("MacBook") ? "laptopcomputer" : "mic"
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
