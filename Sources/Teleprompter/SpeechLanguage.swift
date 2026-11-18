import AppKit
import Speech
import SwiftUI

enum SpeechLanguage {
    static let identifiers = Set(SFSpeechRecognizer.supportedLocales().map { canonical($0.identifier) })
        .sorted { name($0).localizedStandardCompare(name($1)) == .orderedAscending }

    static func canonical(_ identifier: String) -> String {
        Locale(identifier: identifier).identifier(.bcp47)
    }

    static func name(_ identifier: String) -> String {
        Locale.current.localizedString(forIdentifier: identifier) ?? identifier
    }

    static func initialSelection(_ saved: String?) -> String {
        if let saved, identifiers.contains(canonical(saved)) { return canonical(saved) }
        return ["es-ES", "en-US"].first(where: identifiers.contains) ?? identifiers.first ?? "es-ES"
    }

    static func openDictationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct SpeechLanguagePicker: View {
    let title: String
    @Binding var selection: String

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(SpeechLanguage.identifiers, id: \.self) { identifier in
                Text(SpeechLanguage.name(identifier)).tag(identifier)
            }
        }
        .pickerStyle(.menu)
    }
}
