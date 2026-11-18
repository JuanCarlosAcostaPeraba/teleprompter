import AppKit
import SwiftUI

struct QuickControls: View {
    @ObservedObject var desktop: Desktop
    @ObservedObject var model: Prompter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Teleprompter").font(.headline)
            Button {
                desktop.openReader()
            } label: {
                Label("Abrir lector", systemImage: "play.fill").frame(maxWidth: .infinity)
            }
            .modifier(PrimaryGlassButton(enabled: model.useLiquidGlass))
            HStack {
                Button("Desde el portapapeles", systemImage: "clipboard") { desktop.openReader(fromClipboard: true) }
                Button("Editar guion", systemImage: "square.and.pencil", action: desktop.openEditor)
            }
            Divider()
            ReaderControls(model: model)
            Divider()
            AppAccessControls(desktop: desktop)
            Divider()
            UpdateControls(updater: desktop.updater) {
                Button("Salir") { NSApp.terminate(nil) }
            }
        }
        .padding(15)
        .frame(width: 370)
        .modifier(GlassControls(enabled: model.useLiquidGlass))
    }
}

struct Preferences: View {
    @ObservedObject var desktop: Desktop
    @ObservedObject var model: Prompter

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable().frame(width: 44, height: 44)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Teleprompter").font(.title2.weight(.semibold))
                    Text("Ajustes").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Editar guion", action: desktop.openEditor)
            }
            GroupBox("Lector") { ReaderControls(model: model).padding(5) }
            GroupBox("Acceso a la app") {
                AppAccessControls(desktop: desktop).padding(5)
            }
            GroupBox("Actualizaciones") { UpdateControls(updater: desktop.updater).padding(5) }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 430)
        .modifier(GlassControls(enabled: model.useLiquidGlass))
    }
}

private struct AppAccessControls: View {
    @ObservedObject var desktop: Desktop

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Toggle("Mostrar en el Dock", isOn: $desktop.showDock)
            Toggle("Mostrar en la barra de menús", isOn: $desktop.showMenuBar)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ReaderControls: View {
    @ObservedObject var model: Prompter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SpeechLanguagePicker(title: "Idioma de voz", selection: $model.locale)
            Button("Configurar idiomas en Dictado…", systemImage: "arrow.up.right.square",
                   action: SpeechLanguage.openDictationSettings)
                .help("Abre Ajustes del Sistema → Teclado → Dictado → Idiomas")
            HStack {
                Text("Texto").frame(width: 62, alignment: .leading)
                Slider(value: $model.fontSize, in: 18...72).labelsHidden().accessibilityLabel("Texto")
                Text("\(Int(model.fontSize)) pt").monospacedDigit().frame(width: 43, alignment: .trailing)
            }
            HStack {
                Text("Opacidad").frame(width: 62, alignment: .leading)
                Slider(value: $model.opacity, in: 0.5...1).labelsHidden().accessibilityLabel("Opacidad")
                Text(model.opacity, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit().frame(width: 43, alignment: .trailing)
            }
            HStack {
                Text("Ancho").frame(width: 62, alignment: .leading)
                Slider(value: $model.readerWidth, in: CameraPlacement.readerWidthRange)
                    .labelsHidden().accessibilityLabel("Ancho del lector")
                Text("\(Int(model.readerWidth.rounded())) pt")
                    .monospacedDigit().frame(width: 52, alignment: .trailing)
                Button("Restaurar ancho", systemImage: "arrow.counterclockwise") {
                    model.restoreReaderLayout()
                }
                .labelStyle(.iconOnly)
                .help("Restaurar 435 puntos y centrar debajo de la cámara")
            }
            HighlightColorControl(selection: $model.highlightColor)
            Toggle("Escuchar al abrir el lector", isOn: $model.listenOnOpen)
            if #available(macOS 26, *) {
                Toggle("Liquid Glass", isOn: $model.useLiquidGlass)
            }
            Toggle("Desenfocar el fondo", isOn: $model.blurBackground)
            Toggle("Mostrar transcripción", isOn: $model.showTranscript)
            Toggle("Solicitar exclusión de captura", isOn: $model.limitCapture)
                .help("Se aplica al lector. El efecto depende de la aplicación que captura.")
        }
    }
}

private struct HighlightColorControl: View {
    @Binding var selection: Color
    @State private var hexInput = ""

    private let swatches: [(name: String, rgb: UInt32)] = [
        ("Menta", 0x87F2D4), ("Cielo", 0x8BD8FF), ("Lavanda", 0xC7AEFF),
        ("Rosa", 0xFF9DB7), ("Ámbar", 0xFFD273), ("Blanco", 0xFFFFFF)
    ]

    private var selectedHex: String {
        guard let rgb = NSColor(selection).usingColorSpace(.sRGB) else { return "" }
        return [rgb.redComponent, rgb.greenComponent, rgb.blueComponent]
            .map { String(format: "%02X", Int(($0 * 255).rounded())) }.joined()
    }

    private var customRGB: UInt32? {
        let input = hexInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = input.hasPrefix("#") ? String(input.dropFirst()) : input
        guard digits.utf8.count == 6, digits.utf8.allSatisfy({
            (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0)
        }) else { return nil }
        return UInt32(digits, radix: 16)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Color de resalto")
                Spacer(minLength: 4)
                ForEach(swatches, id: \.rgb) { swatch in
                    let isSelected = selectedHex == String(format: "%06X", swatch.rgb)
                    Button {
                        select(swatch.rgb)
                    } label: {
                        Circle()
                            .fill(Self.color(swatch.rgb))
                            .overlay {
                                Circle().strokeBorder(.primary.opacity(isSelected ? 0.85 : 0.2),
                                                      lineWidth: isSelected ? 2 : 1)
                            }
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(swatch.name)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .help(swatch.name)
                }
            }
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(selection)
                    .frame(width: 18, height: 14)
                    .accessibilityHidden(true)
                TextField("#\(selectedHex)", text: $hexInput)
                    .frame(width: 88)
                    .monospaced()
                    .accessibilityLabel("Color hexadecimal")
                    .help("Introduce seis dígitos hexadecimales, por ejemplo #87F2D4")
                    .onSubmit(applyCustomColor)
                Button("Aplicar", action: applyCustomColor)
                    .disabled(customRGB == nil)
            }
        }
    }

    private static func color(_ rgb: UInt32) -> Color {
        Color(.sRGB, red: Double((rgb >> 16) & 255) / 255,
              green: Double((rgb >> 8) & 255) / 255, blue: Double(rgb & 255) / 255)
    }

    private func applyCustomColor() {
        if let customRGB { select(customRGB) }
    }

    private func select(_ rgb: UInt32) {
        selection = Self.color(rgb)
        hexInput = ""
    }
}
