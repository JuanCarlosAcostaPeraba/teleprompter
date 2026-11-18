import AppKit
import SwiftUI

struct QuickControls: View {
    @ObservedObject var desktop: Desktop
    @ObservedObject var model: Prompter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Teleprompter").font(.headline)
                Spacer()
                Button(action: desktop.openSettings) { Image(systemName: "gearshape") }
                    .help("Ajustes").accessibilityLabel("Ajustes")
            }
            Button {
                desktop.openReader()
            } label: {
                Label("Abrir lector", systemImage: "play.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            HStack {
                Button("Desde el portapapeles", systemImage: "clipboard") { desktop.openReader(fromClipboard: true) }
                Button("Editar", systemImage: "square.and.pencil", action: desktop.openEditor)
            }
            Divider()
            ReaderControls(model: model)
            Divider()
            HStack {
                Button("Ajustes…", action: desktop.openSettings)
                Spacer()
                Button("Salir") { NSApp.terminate(nil) }
            }
        }
        .padding(15)
        .frame(width: 345)
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
                VStack(alignment: .leading, spacing: 7) {
                    Toggle("Mostrar en el Dock", isOn: $desktop.showDock)
                    Toggle("Mostrar en la barra de menús", isOn: $desktop.showMenuBar)
                    Text("Abre Teleprompter desde Spotlight para volver a estos ajustes.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(5)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 430)
    }
}

struct ReaderControls: View {
    @ObservedObject var model: Prompter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Idioma de voz", selection: $model.locale) {
                Text("Español").tag("es-ES")
                Text("English").tag("en-US")
            }
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
            ColorPicker("Color de resalto", selection: $model.highlightColor, supportsOpacity: false)
            Toggle("Escuchar al abrir el lector", isOn: $model.listenOnOpen)
            Toggle("Desenfocar el fondo", isOn: $model.blurBackground)
            Toggle("Mostrar transcripción", isOn: $model.showTranscript)
            Toggle("Solicitar exclusión de captura", isOn: $model.limitCapture)
                .help("Se aplica al lector. El efecto depende de la aplicación que captura.")
        }
    }
}
