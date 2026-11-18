import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }
    var name: String {
        switch self {
        case .english: "English"
        case .spanish: "Español"
        }
    }

    static func initialSelection(_ saved: String?, preferred: [String] = Locale.preferredLanguages) -> Self {
        if let saved, let language = Self(rawValue: saved) { return language }
        for identifier in preferred {
            if let code = Locale(identifier: identifier).language.languageCode?.identifier,
               let language = Self(rawValue: code) {
                return language
            }
        }
        return .english
    }

    private static let bundles: [Self: Bundle] = Dictionary(uniqueKeysWithValues: allCases.map { language in
        let code = language.rawValue
        let url = Bundle.main.url(forResource: code, withExtension: "lproj")
            ?? Bundle.module.url(forResource: code, withExtension: "lproj")
        return (language, url.flatMap(Bundle.init(url:)) ?? .main)
    })

    func text(_ key: String, _ arguments: CVarArg...) -> String {
        let fallback = Self.bundles[.english]?.localizedString(forKey: key, value: nil, table: nil)
        let format = Self.bundles[self]?.localizedString(forKey: key, value: fallback, table: nil) ?? key
        return arguments.isEmpty ? format : String(format: format, locale: locale, arguments: arguments)
    }
}

// Keep messages unresolved so an already visible status or error can change language.
struct LocalizedMessage {
    let resolve: (AppLanguage) -> String

    init(_ key: String) {
        self.init { $0.text(key) }
    }

    init(_ resolve: @escaping (AppLanguage) -> String) {
        self.resolve = resolve
    }
}

private struct AppLanguageKey: EnvironmentKey {
    static let defaultValue = AppLanguage.initialSelection(nil)
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }
}

struct LocalizedContent<Content: View>: View {
    @ObservedObject var model: Prompter
    let content: Content

    var body: some View {
        content
            .environment(\.appLanguage, model.interfaceLanguage)
            .environment(\.locale, model.interfaceLanguage.locale)
    }
}
