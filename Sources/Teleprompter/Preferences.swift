import AppKit
import SwiftUI

enum SettingsSection: String, CaseIterable {
    case reader, voice, app

    var titleKey: String {
        switch self {
        case .reader: "reader.settings"
        case .voice: "speech.shortLabel"
        case .app: "settings.appSection"
        }
    }

    var icon: String {
        switch self {
        case .reader: "text.alignleft"
        case .voice: "waveform"
        case .app: "gearshape"
        }
    }
}

struct Preferences: View {
    @Environment(\.appLanguage) private var language
    @ObservedObject var desktop: Desktop
    @ObservedObject var model: Prompter
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            header
            sectionPicker
            if compact {
                sectionContents
            } else {
                ScrollView { sectionContents }
            }
            Divider()
            UpdateControls(updater: desktop.updater) {
                if compact {
                    Button(language.text("menu.quit")) { NSApp.terminate(nil) }
                }
            }
        }
        .padding(compact ? 16 : 20)
        .frame(width: compact ? 382 : 460)
        .modifier(GlassControls(enabled: model.useLiquidGlass))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 34, height: 34)
                    .accessibilityHidden(true)
                Text("Teleprompter")
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
            }
            HStack(spacing: 8) {
                Button {
                    desktop.openReader()
                } label: {
                    Label(language.text("reader.open"), systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .modifier(PrimaryGlassButton(enabled: model.useLiquidGlass))

                Button(language.text("reader.fromClipboard"), systemImage: "clipboard") {
                    desktop.openReader(fromClipboard: true)
                }
                .labelStyle(.iconOnly)
                .help(language.text("reader.fromClipboard"))

                Button(language.text("script.edit"), systemImage: "square.and.pencil", action: desktop.openEditor)
                    .labelStyle(.iconOnly)
                    .help(language.text("script.edit"))
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(.teal.opacity(0.09))
        }
    }

    private var sectionPicker: some View {
        HStack(spacing: 4) {
            ForEach(SettingsSection.allCases, id: \.self) { section in
                let selected = desktop.settingsSection == section
                Button {
                    desktop.settingsSection = section
                } label: {
                    Label(language.text(section.titleKey), systemImage: section.icon)
                        .font(.callout.weight(selected ? .semibold : .regular))
                        .foregroundStyle(selected ? .primary : .secondary)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(.teal.opacity(selected ? 0.16 : 0), in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var sectionContents: some View {
        switch desktop.settingsSection {
        case .reader:
            VStack(spacing: 12) {
                SettingsCard(title: language.text("settings.appearance")) {
                    readerSliders
                    Divider()
                    HighlightColorControl(selection: $model.highlightColor)
                }
                SettingsCard {
                    DisclosureGroup(language.text("settings.effects")) {
                        VStack(spacing: 10) {
                            settingToggle(language.text("reader.blur"), isOn: $model.blurBackground)
                            if #available(macOS 26, *) {
                                settingToggle("Liquid Glass", isOn: $model.useLiquidGlass)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
        case .voice:
            VStack(spacing: 12) {
                SettingsCard {
                    SpeechLanguagePicker(title: language.text("speech.language"), selection: $model.locale)
                    Button(language.text("speech.configure"), systemImage: "arrow.up.right.square",
                           action: SpeechLanguage.openDictationSettings)
                        .buttonStyle(.link)
                        .help(language.text("speech.configureHelp"))
                }
                SettingsCard {
                    settingToggle(language.text("reader.listenOnOpen"), isOn: $model.listenOnOpen)
                    settingToggle(language.text("reader.showTranscript"), isOn: $model.showTranscript)
                }
            }
        case .app:
            VStack(spacing: 12) {
                SettingsCard {
                    AppLanguagePicker(selection: $model.interfaceLanguage)
                    Divider()
                    settingToggle(language.text("settings.showDock"), isOn: $desktop.showDock)
                    settingToggle(language.text("settings.showMenuBar"), isOn: $desktop.showMenuBar)
                }
                SettingsCard {
                    settingToggle(language.text("reader.limitCapture"), isOn: $model.limitCapture)
                        .help(language.text("reader.limitCaptureHelp"))
                }
            }
        }
    }

    private var readerSliders: some View {
        VStack(spacing: 9) {
            slider("reader.textSize", value: $model.fontSize, in: 18...72, displayValue: "\(Int(model.fontSize)) pt")
            slider("reader.opacity", value: $model.opacity, in: 0.5...1,
                   displayValue: model.opacity.formatted(.percent.precision(.fractionLength(0)).locale(language.locale)))
            slider("reader.width", value: $model.readerWidth, in: CameraPlacement.readerWidthRange,
                   displayValue: "\(Int(model.readerWidth.rounded())) pt", reset: model.restoreReaderLayout)
        }
    }

    private func slider(_ labelKey: String, value: Binding<Double>, in range: ClosedRange<Double>,
                        displayValue: String, reset: (() -> Void)? = nil) -> some View {
        let label = language.text(labelKey)
        return HStack(spacing: 8) {
            Text(label).frame(width: 61, alignment: .leading)
            Slider(value: value, in: range)
                .labelsHidden()
                .accessibilityLabel(reset == nil ? label : language.text("reader.widthAccessibility"))
                .tint(.teal)
            Text(displayValue)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing)
            Color.clear
                .frame(width: 24, height: 24)
                .overlay {
                    if let reset {
                        Button(language.text("reader.resetWidth"), systemImage: "arrow.counterclockwise", action: reset)
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                            .help(language.text("reader.resetWidthHelp"))
                    }
                }
        }
    }

    private func settingToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.switch)
        .tint(.teal)
    }
}

private struct SettingsCard<Content: View>: View {
    var title: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 13))
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
            DisclosureGroup(language.text("reader.hex")) {
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
                    Spacer(minLength: 0)
                }
                .padding(.top, 6)
            }
            .font(.callout)
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
