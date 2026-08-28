import Combine
import Foundation

/// The languages shipped in the first localized Pickly release.
///
/// Keep the app locale, Open Food Facts language, and App Store locale in one
/// value so that a new endpoint cannot accidentally derive display language
/// from the user's market country.
nonisolated enum PicklyLanguage: String, CaseIterable, Codable, Hashable, Sendable {
    case en
    case fr
    case de
    case es
    case it
    case ptPT = "pt-PT"
    case da
    case pl
    case cs

    var openFoodFactsCode: String {
        switch self {
        case .ptPT:
            return "pt"
        default:
            return rawValue
        }
    }

    var localeIdentifier: String { rawValue }

    var appStoreLocaleIdentifier: String {
        switch self {
        case .en:
            return "en-US"
        case .es:
            return "es-ES"
        default:
            return rawValue
        }
    }

    static func resolve(
        preferredLocalizations: [String] = Bundle.main.preferredLocalizations,
        locale: Locale = .current
    ) -> PicklyLanguage {
        for identifier in preferredLocalizations {
            if let language = from(identifier: identifier) {
                return language
            }
        }

        if let languageCode = locale.language.languageCode,
           let language = from(identifier: languageCode.identifier) {
            return language
        }

        return .en
    }

    static func from(identifier: String) -> PicklyLanguage? {
        let normalized = identifier.replacingOccurrences(of: "_", with: "-").lowercased()
        switch normalized {
        case "en", "en-us", "en-gb", "en-au", "en-ca":
            return .en
        case "fr", "fr-fr", "fr-ca":
            return .fr
        case "de", "de-de", "de-at", "de-ch":
            return .de
        case "es", "es-es", "es-mx":
            return .es
        case "it", "it-it":
            return .it
        case "pt", "pt-pt", "pt-br":
            // The catalog ships one Portuguese variant for the first release.
            // Use it for both Portugal and Brazil instead of silently falling
            // back to English when the device reports `pt-BR`.
            return .ptPT
        case "da", "da-dk":
            return .da
        case "pl", "pl-pl":
            return .pl
        case "cs", "cs-cz":
            return .cs
        default:
            return nil
        }
    }
}

/// The in-app language choice. `system` follows iOS's preferred app/device
/// languages and resolves to English when none of the shipped localizations
/// match.
nonisolated enum PicklyLanguageSelection: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case system
    case en
    case fr
    case de
    case es
    case it
    case ptPT = "pt-PT"
    case da
    case pl
    case cs

    static let storageKey = "pickly.app-language.v1"

    var id: String { rawValue }

    var resolvedLanguage: PicklyLanguage? {
        switch self {
        case .system:
            return nil
        default:
            return PicklyLanguage(rawValue: rawValue)
        }
    }

    /// Native language names make the picker understandable even before a
    /// user changes the app language.
    var nativeName: String {
        switch self {
        case .system: return PicklyCopy.localized("System Default")
        case .en: return "English"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .es: return "Español"
        case .it: return "Italiano"
        case .ptPT: return "Português (Portugal)"
        case .da: return "Dansk"
        case .pl: return "Polski"
        case .cs: return "Čeština"
        }
    }
}

@MainActor
final class PicklyLanguageStore: ObservableObject {
    @Published var selection: PicklyLanguageSelection {
        didSet { persist() }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let rawValue = defaults.string(forKey: PicklyLanguageSelection.storageKey),
           let storedSelection = PicklyLanguageSelection(rawValue: rawValue) {
            selection = storedSelection
        } else {
            selection = .system
        }
    }

    var language: PicklyLanguage {
        selection.resolvedLanguage ?? PicklyLanguage.resolve()
    }

    var locale: Locale {
        Locale(identifier: language.localeIdentifier)
    }

    var localeContext: PicklyLocaleContext {
        PicklyLocaleContext(language: language, regionCode: Locale.current.region?.identifier)
    }

    func resetToSystem() {
        selection = .system
    }

    private func persist() {
        defaults.set(selection.rawValue, forKey: PicklyLanguageSelection.storageKey)
    }
}

nonisolated struct PicklyLocaleContext: Hashable, Sendable {
    let language: PicklyLanguage
    let regionCode: String

    init(language: PicklyLanguage, regionCode: String? = Locale.current.region?.identifier) {
        self.language = language
        self.regionCode = regionCode?.uppercased() ?? ""
    }

    static var current: PicklyLocaleContext {
        let selection = UserDefaults.standard.string(forKey: PicklyLanguageSelection.storageKey)
            .flatMap(PicklyLanguageSelection.init(rawValue:))
        return PicklyLocaleContext(language: selection?.resolvedLanguage ?? PicklyLanguage.resolve())
    }

    var openFoodFactsLanguageCode: String { language.openFoodFactsCode }

    /// The market is a ranking hint, never a hard filter for barcode lookup.
    var preferredCountryTags: [String] {
        var tags: [String] = []
        if let marketTag = Self.countryTag(for: regionCode) {
            tags.append(marketTag)
        }

        if !tags.contains("en:united-kingdom") {
            tags.append("en:united-kingdom")
        }
        return tags
    }

    private static func countryTag(for regionCode: String) -> String? {
        let tags: [String: String] = [
            "AT": "en:austria",
            "AU": "en:australia",
            "BR": "en:brazil",
            "BE": "en:belgium",
            "CA": "en:canada",
            "CH": "en:switzerland",
            "CZ": "en:czech-republic",
            "DE": "en:germany",
            "DK": "en:denmark",
            "ES": "en:spain",
            "FR": "en:france",
            "GB": "en:united-kingdom",
            "IE": "en:ireland",
            "IT": "en:italy",
            "NL": "en:netherlands",
            "PL": "en:poland",
            "PT": "en:portugal",
            "US": "en:united-states"
        ]
        return tags[regionCode]
    }
}
