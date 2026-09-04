import Foundation

/// Small shared wrapper for strings that are assembled outside SwiftUI.
/// SwiftUI text literals are localized automatically, while service results,
/// accessibility summaries, and persisted view models need an explicit call.
nonisolated enum PicklyCopy {
    /// Returns the resolved app locale rather than `Locale.current` directly.
    /// This matters for supported aliases such as `pt-BR`: the shipped String
    /// Catalog uses `pt-PT`, while the product should still remain Portuguese.
    static var appLocale: Locale {
        Locale(identifier: PicklyLocaleContext.current.language.localeIdentifier)
    }

    static func localized(_ key: String, locale: Locale? = nil) -> String {
        let resolvedLocale = locale ?? appLocale
        let language = PicklyLanguage.from(identifier: resolvedLocale.identifier) ?? .en

        guard let localizationURL = Bundle.main.url(
            forResource: language.localeIdentifier,
            withExtension: "lproj"
        ), let localizationBundle = Bundle(url: localizationURL) else {
            return Bundle.main.localizedString(
                forKey: key,
                value: key,
                table: "Localizable"
            )
        }

        return localizationBundle.localizedString(
            forKey: key,
            value: key,
            table: "Localizable"
        )
    }

    static func format(
        _ key: String,
        locale: Locale? = nil,
        _ arguments: CVarArg...
    ) -> String {
        let resolvedLocale = locale ?? appLocale
        let template = localized(key, locale: resolvedLocale)
        guard !arguments.isEmpty else { return template }
        return String(format: template, locale: resolvedLocale, arguments: arguments)
    }
}
