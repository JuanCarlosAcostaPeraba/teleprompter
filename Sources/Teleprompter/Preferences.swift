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
            .buttonStyle(.borderedProminent)
            HStack {
                Button("Desde el portapapeles", systemImage: "clipboard") { desktop.openReader(fromClipboard: true) }
                Button("Editar guion", systemImage: "square.and.pencil", action: desktop.openEditor)
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ReaderControls(model: model)
                    Divider()
                    AppAccessControls(desktop: desktop)
                }
            }
            .frame(height: 390)
            Divider()
            HStack {
                Spacer()
                Button("Salir") { NSApp.terminate(nil) }
            }
        }
        .padding(15)
        .frame(width: 370)
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
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 430)
    }
}

private struct AppAccessControls: View {
    @ObservedObject var desktop: Desktop

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Toggle("Mostrar en el Dock", isOn: $desktop.showDock)
            Toggle("Mostrar en la barra de menús", isOn: $desktop.showMenuBar)
            Text("También puedes abrir Ajustes desde Raycast o Spotlight.")
                .font(.caption).foregroundStyle(.secondary)
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
                .buttonStyle(.link)
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
            ColorPicker("Color de resalto", selection: $model.highlightColor, supportsOpacity: false)
            Toggle("Escuchar al abrir el lector", isOn: $model.listenOnOpen)
            Toggle("Desenfocar el fondo", isOn: $model.blurBackground)
            Toggle("Mostrar transcripción", isOn: $model.showTranscript)
            Toggle("Solicitar exclusión de captura", isOn: $model.limitCapture)
                .help("Se aplica al lector. El efecto depende de la aplicación que captura.")
        }
    }
}
