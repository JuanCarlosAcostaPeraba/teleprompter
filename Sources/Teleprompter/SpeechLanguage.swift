import AppKit
import Speech
import SwiftUI

enum SpeechLanguage {
    private static let identifiers = Set(SFSpeechRecognizer.supportedLocales().map { canonical($0.identifier) })

    static let options = Dictionary(uniqueKeysWithValues: AppLanguage.allCases.map { language in
        let locale = language.locale
        let localized = identifiers.map { (id: $0, name: name($0, in: locale)) }.sorted { lhs, rhs in
            let order = lhs.name.compare(rhs.name, options: [.caseInsensitive, .numeric], locale: locale)
            return order == .orderedSame ? lhs.id < rhs.id : order == .orderedAscending
        }
        return (language, localized)
    })

    static func canonical(_ identifier: String) -> String {
        Locale(identifier: identifier).identifier(.bcp47)
    }

    static func name(_ identifier: String, in locale: Locale) -> String {
        locale.localizedString(forIdentifier: identifier) ?? identifier
    }

    static func initialSelection(_ saved: String?) -> String {
        if let saved, identifiers.contains(canonical(saved)) { return canonical(saved) }
        let defaults = AppLanguage.initialSelection(nil) == .spanish ? ["es-ES", "en-US"] : ["en-US", "es-ES"]
        return defaults.first(where: identifiers.contains) ?? identifiers.min() ?? defaults[0]
    }

    static func openDictationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct SpeechLanguagePicker: View {
    @Environment(\.appLanguage) private var language
    let title: String
    @Binding var selection: String

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(SpeechLanguage.options[language] ?? [], id: \.id) { option in
                Text(option.name).tag(option.id)
            }
        }
        .pickerStyle(.menu)
    }
}
