import AppKit
import SwiftUI

struct QuickControls: View {
    @Environment(\.appLanguage) private var language
    @ObservedObject var desktop: Desktop
    @ObservedObject var model: Prompter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Teleprompter").font(.headline)
            AppLanguagePicker(selection: $model.interfaceLanguage)
            Button {
                desktop.openReader()
            } label: {
                Label(language.text("reader.open"), systemImage: "play.fill").frame(maxWidth: .infinity)
            }
            .modifier(PrimaryGlassButton(enabled: model.useLiquidGlass))
            HStack {
                Button(language.text("reader.fromClipboard"), systemImage: "clipboard") { desktop.openReader(fromClipboard: true) }
                Button(language.text("script.edit"), systemImage: "square.and.pencil", action: desktop.openEditor)
            }
            Divider()
            ReaderControls(model: model)
            Divider()
            AppAccessControls(desktop: desktop)
            Divider()
            UpdateControls(updater: desktop.updater) {
                Button(language.text("menu.quit")) { NSApp.terminate(nil) }
            }
        }
        .padding(15)
        .frame(width: 370)
        .modifier(GlassControls(enabled: model.useLiquidGlass))
    }
}

struct Preferences: View {
    @Environment(\.appLanguage) private var language
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
                    Text(language.text("settings")).foregroundStyle(.secondary)
                }
                Spacer()
                Button(language.text("script.edit"), action: desktop.openEditor)
            }
            AppLanguagePicker(selection: $model.interfaceLanguage)
            GroupBox(language.text("reader.settings")) { ReaderControls(model: model).padding(5) }
            GroupBox(language.text("settings.appAccess")) {
                AppAccessControls(desktop: desktop).padding(5)
            }
            GroupBox(language.text("updates.title")) { UpdateControls(updater: desktop.updater).padding(5) }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 430)
        .modifier(GlassControls(enabled: model.useLiquidGlass))
    }
}

private struct AppAccessControls: View {
    @Environment(\.appLanguage) private var language
    @ObservedObject var desktop: Desktop

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Toggle(language.text("settings.showDock"), isOn: $desktop.showDock)
            Toggle(language.text("settings.showMenuBar"), isOn: $desktop.showMenuBar)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ReaderControls: View {
    @Environment(\.appLanguage) private var language
    @ObservedObject var model: Prompter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SpeechLanguagePicker(title: language.text("speech.language"), selection: $model.locale)
            Button(language.text("speech.configure"), systemImage: "arrow.up.right.square",
                   action: SpeechLanguage.openDictationSettings)
                .help(language.text("speech.configureHelp"))
            HStack {
                Text(language.text("reader.textSize")).frame(width: 62, alignment: .leading)
                Slider(value: $model.fontSize, in: 18...72).labelsHidden().accessibilityLabel(language.text("reader.textSize"))
                Text("\(Int(model.fontSize)) pt").monospacedDigit().frame(width: 43, alignment: .trailing)
            }
            HStack {
                Text(language.text("reader.opacity")).frame(width: 62, alignment: .leading)
                Slider(value: $model.opacity, in: 0.5...1).labelsHidden().accessibilityLabel(language.text("reader.opacity"))
                Text(model.opacity, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit().frame(width: 43, alignment: .trailing)
            }
            HStack {
                Text(language.text("reader.width")).frame(width: 62, alignment: .leading)
                Slider(value: $model.readerWidth, in: CameraPlacement.readerWidthRange)
                    .labelsHidden().accessibilityLabel(language.text("reader.widthAccessibility"))
                Text("\(Int(model.readerWidth.rounded())) pt")
                    .monospacedDigit().frame(width: 52, alignment: .trailing)
                Button(language.text("reader.resetWidth"), systemImage: "arrow.counterclockwise") {
                    model.restoreReaderLayout()
                }
                .labelStyle(.iconOnly)
                .help(language.text("reader.resetWidthHelp"))
            }
            HighlightColorControl(selection: $model.highlightColor)
            Toggle(language.text("reader.listenOnOpen"), isOn: $model.listenOnOpen)
            if #available(macOS 26, *) {
                Toggle("Liquid Glass", isOn: $model.useLiquidGlass)
            }
            Toggle(language.text("reader.blur"), isOn: $model.blurBackground)
            Toggle(language.text("reader.showTranscript"), isOn: $model.showTranscript)
            Toggle(language.text("reader.limitCapture"), isOn: $model.limitCapture)
                .help(language.text("reader.limitCaptureHelp"))
        }
    }
}

private struct AppLanguagePicker: View {
    @Environment(\.appLanguage) private var language
    @Binding var selection: AppLanguage

    var body: some View {
        Picker(language.text("settings.interfaceLanguage"), selection: $selection) {
            ForEach(AppLanguage.allCases) { option in
                Text(option.name).tag(option)
            }
        }
        .pickerStyle(.menu)
    }
}

private struct HighlightColorControl: View {
    @Environment(\.appLanguage) private var language
    @Binding var selection: Color
    @State private var hexInput = ""

    private let swatches: [(nameKey: String, rgb: UInt32)] = [
        ("color.mint", 0x87F2D4), ("color.sky", 0x8BD8FF), ("color.lavender", 0xC7AEFF),
        ("color.pink", 0xFF9DB7), ("color.amber", 0xFFD273), ("color.white", 0xFFFFFF)
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
                Text(language.text("reader.highlight"))
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
                    .accessibilityLabel(language.text(swatch.nameKey))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .help(language.text(swatch.nameKey))
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
                    .accessibilityLabel(language.text("reader.hex"))
                    .help(language.text("reader.hexHelp"))
                    .onSubmit(applyCustomColor)
                Button(language.text("reader.apply"), action: applyCustomColor)
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
