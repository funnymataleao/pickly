import SwiftUI

enum ResultStatus: String, Hashable {
    case good
    case medium
    case bad
    case avoid
    case unknown

    var color: Color {
        palette.accent
    }

    var softColor: Color {
        palette.fill
    }

    var foregroundColor: Color {
        palette.foreground
    }

    var borderColor: Color {
        palette.border
    }

    private var palette: PicklyColor.StatusPalette {
        PicklyColor.statusPalette(semanticStatus)
    }

    private var semanticStatus: PicklyColor.SemanticStatus {
        switch self {
        case .good:
            return .positive
        case .medium:
            return .attention
        case .bad, .avoid:
            return .attention
        case .unknown:
            return .neutral
        }
    }

    var badgeText: String {
        switch self {
        case .good:
            return PicklyCopy.localized("Good")
        case .medium:
            return PicklyCopy.localized("Neutral")
        case .bad:
            return PicklyCopy.localized("Watch")
        case .avoid:
            return PicklyCopy.localized("Watch")
        case .unknown:
            return PicklyCopy.localized("Neutral")
        }
    }
}

struct ProductInsight: Identifiable, Hashable {
    let id: String
    let icon: String
    let title: String
    let status: String
    let value: String
    let explanation: String
    let resultStatus: ResultStatus

    var visualPalette: PicklyColor.StatusPalette {
        PicklyColor.insightPalette(tone)
    }

    private var tone: PicklyColor.InsightTone {
        switch id {
        case "sodium":
            return .sodium
        case "sugar":
            return .sugar
        case "ingredients":
            return .additives
        case "protein-fiber":
            return .proteinFiber
        default:
            return .neutral
        }
    }
}

struct IngredientAnalysis: Identifiable, Hashable {
    let id: String
    let name: String
    let explanation: String
    let status: ResultStatus

    var badge: String {
        status.badgeText
    }
}

struct NutritionFact: Identifiable, Hashable {
    let id: String
    let title: String
    let value: String
    let percent: Int?
    let status: ResultStatus
    let isKeyFact: Bool

    var progress: Double {
        guard let percent else {
            return 0
        }

        return min(Double(percent) / 100, 1)
    }
}

struct ProductQuickFact: Identifiable, Hashable {
    let id: String
    let title: String
    let value: String
    let systemImage: String
}

nonisolated enum ProductFactFormatter {
    private static let localizedAllergenKeys: [String: String] = [
        "milk": "Milk",
        "nuts": "Tree nuts",
        "tree-nuts": "Tree nuts",
        "peanuts": "Peanuts",
        "gluten": "Gluten",
        "wheat": "Wheat",
        "eggs": "Eggs",
        "soy": "Soy",
        "soybean": "Soy",
        "soybeans": "Soy",
        "fish": "Fish",
        "crustaceans": "Crustaceans",
        "molluscs": "Molluscs",
        "celery": "Celery",
        "mustard": "Mustard",
        "sesame": "Sesame",
        "sesame-seeds": "Sesame",
        "sulfites": "Sulphites",
        "sulphites": "Sulphites",
        "sulphur-dioxide-and-sulphites": "Sulphites",
        "lupin": "Lupin"
    ]

    static func displayName(for rawTag: String) -> String {
        let unscoped = rawTag
            .split(separator: ":", maxSplits: 1)
            .last
            .map(String.init) ?? rawTag
        let normalizedTag = unscoped.lowercased()

        if let localizationKey = localizedAllergenKeys[normalizedTag] {
            return PicklyCopy.localized(localizationKey)
        }

        let cleaned = unscoped
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return rawTag }
        if cleaned.lowercased().hasPrefix("e"),
           cleaned.dropFirst().first?.isNumber == true {
            return "E" + cleaned.dropFirst()
        }
        return cleaned.capitalized(with: PicklyCopy.appLocale)
    }
}

extension Product {
    var quickFacts: [ProductQuickFact] {
        var facts: [ProductQuickFact] = []

        if let quantity = self.facts.quantity {
            facts.append(ProductQuickFact(
                id: "quantity",
                title: PicklyCopy.localized("Package"),
                value: quantity,
                systemImage: "shippingbox"
            ))
        }

        if let servingSize = self.facts.servingSize {
            facts.append(ProductQuickFact(
                id: "serving",
                title: PicklyCopy.localized("Serving"),
                value: servingSize,
                systemImage: "fork.knife"
            ))
        }

        if let energy = nutrition.energyKcal100g {
            facts.append(ProductQuickFact(
                id: "energy",
                title: PicklyCopy.localized("Energy"),
                value: "\(energy.formatted(.number.locale(PicklyCopy.appLocale).precision(.fractionLength(0)))) kcal",
                systemImage: "bolt"
            ))
        }

        if let totalFat = nutrition.fat100g {
            facts.append(ProductQuickFact(
                id: "total-fat",
                title: PicklyCopy.localized("Total fat"),
                value: formattedGrams(totalFat),
                systemImage: "drop"
            ))
        }

        return Array(facts.prefix(4))
    }

    var nutritionBasisLabel: String {
        switch facts.nutritionBasis {
        case .per100g:
            return PicklyCopy.localized("Per 100 g")
        case .per100ml:
            return PicklyCopy.localized("Per 100 ml")
        case .perServing:
            return PicklyCopy.localized("Per serving")
        case .unknown:
            return PicklyCopy.localized("Basis not specified")
        }
    }

    var resultDisplayName: String {
        name == "Unknown product"
            ? PicklyCopy.localized("Product partially recognized")
            : name
    }

    var resultSubtitle: String {
        name == "Unknown product"
            ? PicklyCopy.localized("Partial product details")
            : displayBrandName
    }

    var resultVerdict: String {
        localizedVerdict
    }

    var resultHeadline: String {
        if isLimitedData {
            return PicklyCopy.localized("Limited data")
        }

        guard let score else {
            return PicklyCopy.localized("Limited data")
        }

        switch score {
        case 85...100:
            return PicklyCopy.localized("Great choice")
        case 70..<85:
            return PicklyCopy.localized("Good choice")
        case 50..<70:
            return PicklyCopy.localized("Okay for occasionally")
        default:
            return PicklyCopy.localized("Worth comparing")
        }
    }

    var resultSummary: String {
        if isLimitedData {
            return PicklyCopy.localized("We don't have enough nutrition or ingredient data to score this product confidently.")
        }

        return summary
    }

    var confidenceText: String {
        PicklyCopy.format("Confidence: %@", locale: PicklyCopy.appLocale, PicklyCopy.localized(confidence))
    }

    var resultScoreColor: Color {
        PicklyColor.ratingPalette(forScore: score, isLimitedData: isLimitedData).accent
    }

    var resultScoreFillColor: Color {
        PicklyColor.verdictFill(score: score, isLimitedData: isLimitedData)
    }

    var resultScoreForegroundColor: Color {
        PicklyColor.verdictForeground(score: score, isLimitedData: isLimitedData)
    }

    var keyInsights: [ProductInsight] {
        [
            sodiumInsight,
            sugarInsight,
            additivesInsight,
            proteinFiberInsight
        ]
    }

    var ingredientAnalyses: [IngredientAnalysis] {
        ingredients.enumerated().map { index, ingredient in
            IngredientAnalysis(
                id: "\(id)-ingredient-\(index)",
                name: ingredient,
                explanation: ingredientExplanation(for: ingredient),
                status: ingredientStatus(for: ingredient)
            )
        }
    }

    var nutritionFacts: [NutritionFact] {
        let sodiumStatus: ResultStatus = {
            guard let salt = nutrition.salt100g else {
                return .unknown
            }

            switch salt {
            case ..<0.3:
                return .good
            case 0.3..<1.0:
                return .medium
            default:
                return .bad
            }
        }()

        var facts: [NutritionFact] = []

        if let energy = nutrition.energyKcal100g {
            facts.append(NutritionFact(
                id: "energy-kcal",
                title: PicklyCopy.localized("Energy"),
                value: "\(energy.formatted(.number.locale(PicklyCopy.appLocale).precision(.fractionLength(0)))) kcal",
                percent: nil,
                status: .unknown,
                isKeyFact: true
            ))
        }

        if let sugar = sugarForScoring {
            facts.append(NutritionFact(
                id: "sugar",
                title: PicklyCopy.localized(sugarLabel == "added sugar" ? "Added sugar" : "Sugar"),
                value: formattedGrams(sugar),
                percent: nil,
                status: statusForSugar,
                isKeyFact: true
            ))
        }

        if let salt = nutrition.salt100g {
            facts.append(NutritionFact(
                id: "salt",
                title: PicklyCopy.localized("Salt"),
                value: formattedGrams(salt),
                percent: nil,
                status: sodiumStatus,
                isKeyFact: true
            ))
        }

        if let protein = nutrition.proteins100g {
            facts.append(NutritionFact(
                id: "protein",
                title: PicklyCopy.localized("Protein"),
                value: formattedGrams(protein),
                percent: nil,
                status: statusForProteinFiber,
                isKeyFact: true
            ))
        }

        if let totalFat = nutrition.fat100g {
            facts.append(NutritionFact(
                id: "total-fat",
                title: PicklyCopy.localized("Total fat"),
                value: formattedGrams(totalFat),
                percent: nil,
                status: .unknown,
                isKeyFact: false
            ))
        }

        if let saturatedFat = nutrition.saturatedFat100g {
            facts.append(NutritionFact(
                id: "saturated-fat",
                title: PicklyCopy.localized("Saturated fat"),
                value: formattedGrams(saturatedFat),
                percent: nil,
                status: statusForSaturatedFat,
                isKeyFact: false
            ))
        }

        if let carbohydrates = nutrition.carbohydrates100g {
            facts.append(NutritionFact(
                id: "carbohydrates",
                title: PicklyCopy.localized("Carbohydrates"),
                value: formattedGrams(carbohydrates),
                percent: nil,
                status: .unknown,
                isKeyFact: false
            ))
        }

        if let fiber = nutrition.fiber100g {
            facts.append(NutritionFact(
                id: "fiber",
                title: PicklyCopy.localized("Fiber"),
                value: formattedGrams(fiber),
                percent: nil,
                status: statusForFiber,
                isKeyFact: false
            ))
        }

        if let sodium = nutrition.sodium100g {
            let milligrams = sodium * 1_000
            facts.append(NutritionFact(
                id: "sodium",
                title: PicklyCopy.localized("Sodium"),
                value: "\(milligrams.formatted(.number.locale(PicklyCopy.appLocale).precision(.fractionLength(0...1)))) mg",
                percent: nil,
                status: sodiumStatus,
                isKeyFact: false
            ))
        }

        if let energyKJ = nutrition.energyKJ100g {
            facts.append(NutritionFact(
                id: "energy-kj",
                title: PicklyCopy.localized("Energy (kJ)"),
                value: "\(energyKJ.formatted(.number.locale(PicklyCopy.appLocale).precision(.fractionLength(0)))) kJ",
                percent: nil,
                status: .unknown,
                isKeyFact: false
            ))
        }

        return facts
    }

    var recommendations: [String] {
        var items: [String] = []

        if let salt = nutrition.salt100g, salt >= 1.0 {
            items.append(PicklyCopy.localized("Pick lower sodium"))
        }

        if let sugar = sugarForScoring, sugar >= 12 {
            items.append(PicklyCopy.localized("Pick lower sugar"))
        }

        if ingredients.count > 12 {
            items.append(PicklyCopy.localized("Prefer shorter lists"))
        }

        if ingredientAnalyses.contains(where: { $0.status == .bad || $0.status == .avoid }) {
            items.append(PicklyCopy.localized("Prefer fewer additives"))
        }

        return Array(items.prefix(3))
    }

    func forYouMessages(preferences: UserPreferences) -> [String] {
        var messages = forYouNotes

        if preferences.lowSugar, let sugar = sugarForScoring, sugar >= 12 {
            messages.append(PicklyCopy.localized("May not be the best choice if you're reducing sugar"))
        }

        if preferences.lowSodium, let salt = nutrition.salt100g, salt >= 1.0 {
            messages.append(PicklyCopy.localized("You might prefer a lower sodium option"))
        }

        if preferences.sensitiveDigestion, ingredients.count > 8 {
            messages.append(PicklyCopy.localized("Gentler picks usually have shorter ingredient lists"))
        }

        if preferences.glutenFree {
            switch dietary.glutenFree {
            case .confirmed:
                messages.append(PicklyCopy.localized("Fits your gluten-free preference"))
            case .notSuitable:
                messages.append(PicklyCopy.localized("May not fit a gluten-free preference"))
            case .unknown:
                break
            }
        }

        if preferences.lactoseFree {
            switch dietary.lactoseFree {
            case .confirmed:
                messages.append(PicklyCopy.localized("Fits your lactose-free preference"))
            case .notSuitable:
                messages.append(PicklyCopy.localized("May not fit a lactose-free preference"))
            case .unknown:
                break
            }
        }

        if preferences.vegan {
            switch dietary.vegan {
            case .confirmed:
                messages.append(PicklyCopy.localized("Fits your vegan preference"))
            case .notSuitable:
                messages.append(PicklyCopy.localized("May not fit a vegan preference"))
            case .unknown:
                break
            }
        }

        if preferences.vegetarian {
            switch dietary.vegetarian {
            case .confirmed:
                messages.append(PicklyCopy.localized("Fits your vegetarian preference"))
            case .notSuitable:
                messages.append(PicklyCopy.localized("May not fit a vegetarian preference"))
            case .unknown:
                break
            }
        }

        return Array(uniqueMessages(messages).prefix(3))
    }

    private var sodiumInsight: ProductInsight {
        guard let salt = nutrition.salt100g else {
            return ProductInsight(
                id: "sodium",
                icon: "drop",
                title: PicklyCopy.localized("Sodium"),
                status: PicklyCopy.localized("Limited"),
                value: PicklyCopy.localized("Not available"),
                explanation: PicklyCopy.localized("Sodium data is not available."),
                resultStatus: .unknown
            )
        }

        switch salt {
        case ..<0.3:
            return ProductInsight(
                id: "sodium",
                icon: "drop",
                title: PicklyCopy.localized("Sodium"),
                status: PicklyCopy.localized("Low"),
                value: "\(formattedGrams(salt)) \(PicklyCopy.localized("salt"))",
                explanation: PicklyCopy.localized("Low salt per 100g."),
                resultStatus: .good
            )
        case 0.3..<1.0:
            return ProductInsight(
                id: "sodium",
                icon: "drop",
                title: PicklyCopy.localized("Sodium"),
                status: PicklyCopy.localized("Moderate"),
                value: "\(formattedGrams(salt)) \(PicklyCopy.localized("salt"))",
                explanation: PicklyCopy.localized("Reasonable, but worth checking serving size."),
                resultStatus: .medium
            )
        default:
            return ProductInsight(
                id: "sodium",
                icon: "drop",
                title: PicklyCopy.localized("Sodium"),
                status: PicklyCopy.localized("High"),
                value: "\(formattedGrams(salt)) \(PicklyCopy.localized("salt"))",
                explanation: PicklyCopy.localized("Not ideal for daily use if you are limiting sodium."),
                resultStatus: .bad
            )
        }
    }

    private var sugarInsight: ProductInsight {
        guard let sugar = sugarForScoring else {
            return ProductInsight(
                id: "sugar",
                icon: "cube",
                title: PicklyCopy.localized("Sugar"),
                status: PicklyCopy.localized("Limited"),
                value: PicklyCopy.localized("Not available"),
                explanation: PicklyCopy.localized("Sugar data is not available yet."),
                resultStatus: .unknown
            )
        }

        switch sugar {
        case ..<5:
            return ProductInsight(
                id: "sugar",
                icon: "cube",
                title: PicklyCopy.localized(sugarLabel == "added sugar" ? "Added sugar" : "Sugar"),
                status: PicklyCopy.localized("Low"),
                value: formattedGrams(sugar),
                explanation: PicklyCopy.format(
                    "Low %@ per 100g.",
                    PicklyCopy.localized(sugarLabel == "added sugar" ? "added sugar" : "sugar")
                ),
                resultStatus: .good
            )
        case 5..<12:
            return ProductInsight(
                id: "sugar",
                icon: "cube",
                title: PicklyCopy.localized(sugarLabel == "added sugar" ? "Added sugar" : "Sugar"),
                status: PicklyCopy.localized("Moderate"),
                value: formattedGrams(sugar),
                explanation: PicklyCopy.format(
                    "Moderate %@ level per 100g.",
                    PicklyCopy.localized(sugarLabel == "added sugar" ? "added sugar" : "sugar")
                ),
                resultStatus: .medium
            )
        default:
            return ProductInsight(
                id: "sugar",
                icon: "cube",
                title: PicklyCopy.localized(sugarLabel == "added sugar" ? "Added sugar" : "Sugar"),
                status: PicklyCopy.localized("Higher"),
                value: formattedGrams(sugar),
                explanation: PicklyCopy.localized("May not be the best everyday choice if reducing sugar."),
                resultStatus: .bad
            )
        }
    }

    private var additivesInsight: ProductInsight {
        let cautionIngredients = ingredientAnalyses.filter { $0.status == .bad }

        if ingredients.isEmpty {
            return ProductInsight(
                id: "ingredients",
                icon: "list.bullet.rectangle",
                title: PicklyCopy.localized("Ingredients"),
                status: PicklyCopy.localized("Limited"),
                value: PicklyCopy.localized("Not available"),
                explanation: PicklyCopy.localized("Ingredients are not available yet."),
                resultStatus: .unknown
            )
        }

        if cautionIngredients.isEmpty && ingredients.count <= 8 {
            return ProductInsight(
                id: "ingredients",
                icon: "list.bullet.rectangle",
                title: PicklyCopy.localized("Ingredients"),
                status: PicklyCopy.localized("Simple"),
                value: ingredientCountLabel,
                explanation: PicklyCopy.localized("Short ingredient list."),
                resultStatus: .good
            )
        }

        if cautionIngredients.isEmpty {
            return ProductInsight(
                id: "ingredients",
                icon: "list.bullet.rectangle",
                title: PicklyCopy.localized("Ingredients"),
                status: PicklyCopy.localized("Mixed"),
                value: ingredientCountLabel,
                explanation: PicklyCopy.localized("Longer ingredient list than simpler options."),
                resultStatus: .medium
            )
        }

        return ProductInsight(
            id: "ingredients",
            icon: "list.bullet.rectangle",
            title: PicklyCopy.localized("Ingredients"),
            status: PicklyCopy.localized("Watch"),
            value: "\(cautionIngredients.count) \(cautionIngredients.count == 1 ? PicklyCopy.localized("item") : PicklyCopy.localized("items"))",
            explanation: PicklyCopy.localized("Some ingredients may be worth checking."),
            resultStatus: .bad
        )
    }

    private var proteinFiberInsight: ProductInsight {
        let protein = nutrition.proteins100g
        let fiber = nutrition.fiber100g

        guard protein != nil || fiber != nil else {
            return ProductInsight(
                id: "protein-fiber",
                icon: "leaf",
                title: PicklyCopy.localized("Protein"),
                status: PicklyCopy.localized("Limited"),
                value: PicklyCopy.localized("Not available"),
                explanation: PicklyCopy.localized("Protein and fiber data are incomplete."),
                resultStatus: .unknown
            )
        }

        let value = protein.map { "\(formattedGrams($0)) \(PicklyCopy.localized("protein"))" }
            ?? fiber.map { "\(formattedGrams($0)) \(PicklyCopy.localized("fiber"))" }
            ?? PicklyCopy.localized("Not available")

        if (protein ?? 0) >= 10 || (fiber ?? 0) >= 6 {
            return ProductInsight(
                id: "protein-fiber",
                icon: "leaf",
                title: PicklyCopy.localized("Protein"),
                status: PicklyCopy.localized("Helpful"),
                value: value,
                explanation: PicklyCopy.localized("Adds useful protein or fiber."),
                resultStatus: .good
            )
        }

        return ProductInsight(
            id: "protein-fiber",
            icon: "leaf",
            title: PicklyCopy.localized("Protein"),
            status: PicklyCopy.localized("Modest"),
            value: value,
            explanation: PicklyCopy.localized("Some nutrition upside, but not a standout."),
            resultStatus: .medium
        )
    }

    private var statusForSugar: ResultStatus {
        guard let sugar = sugarForScoring else {
            return .unknown
        }

        switch sugar {
        case ..<5:
            return .good
        case 5..<12:
            return .medium
        default:
            return .bad
        }
    }

    private var statusForSaturatedFat: ResultStatus {
        guard let saturatedFat = nutrition.saturatedFat100g else {
            return .unknown
        }

        switch saturatedFat {
        case ..<1.5:
            return .good
        case 1.5..<5:
            return .medium
        default:
            return .bad
        }
    }

    private var statusForFiber: ResultStatus {
        guard let fiber = nutrition.fiber100g else {
            return .unknown
        }

        return fiber >= 3 ? .good : .medium
    }

    private var statusForProteinFiber: ResultStatus {
        guard nutrition.proteins100g != nil || nutrition.fiber100g != nil else {
            return .unknown
        }

        if (nutrition.proteins100g ?? 0) >= 10 || (nutrition.fiber100g ?? 0) >= 6 {
            return .good
        }

        return .medium
    }

    private func ingredientStatus(for ingredient: String) -> ResultStatus {
        let lowercased = ingredient.lowercased()

        if lowercased.contains("partially hydrogenated") || lowercased.contains("hydrogenated") {
            return .avoid
        }

        if lowercased.contains("color")
            || lowercased.contains("colour")
            || lowercased.contains("caramel")
            || lowercased.contains("preservative")
            || lowercased.contains("artificial")
            || lowercased.contains("flavor") {
            return .bad
        }

        if lowercased.contains("sugar")
            || lowercased.contains("syrup")
            || lowercased.contains("salt")
            || lowercased.contains("sodium")
            || lowercased.contains("oil") {
            return .medium
        }

        if lowercased.contains("oat")
            || lowercased.contains("lentil")
            || lowercased.contains("tomato")
            || lowercased.contains("milk")
            || lowercased.contains("culture")
            || lowercased.contains("fiber")
            || lowercased.contains("protein") {
            return .good
        }

        return .unknown
    }

    private func ingredientExplanation(for ingredient: String) -> String {
        let lowercased = ingredient.lowercased()

        if lowercased.contains("sugar") || lowercased.contains("syrup") || lowercased.contains("honey") {
            return PicklyCopy.localized("Adds sweetness and can raise the sugar level.")
        }

        if lowercased.contains("salt") || lowercased.contains("sodium") {
            return PicklyCopy.localized("Adds flavor and can raise sodium.")
        }

        if lowercased.contains("color") || lowercased.contains("colour") || lowercased.contains("caramel") {
            return PicklyCopy.localized("Worth watching if you prefer simpler ingredients.")
        }

        if lowercased.contains("flavor") || lowercased.contains("preservative") || lowercased.contains("artificial") {
            return PicklyCopy.localized("Usually fine, but simpler options may use fewer additives.")
        }

        if lowercased.contains("protein") {
            return PicklyCopy.localized("Helpful protein source.")
        }

        if lowercased.contains("fiber") || lowercased.contains("oat") || lowercased.contains("lentil") {
            return PicklyCopy.localized("Simple ingredient that can add fiber.")
        }

        if lowercased.contains("milk") || lowercased.contains("cream") {
            return PicklyCopy.localized("Dairy ingredient that can add texture and protein.")
        }

        if lowercased.contains("water") {
            return PicklyCopy.localized("Used as a base ingredient.")
        }

        return PicklyCopy.localized("Limited details, treated as neutral for now.")
    }

    private func formattedGrams(_ value: Double) -> String {
        "\(value.formatted(.number.locale(PicklyCopy.appLocale).precision(.fractionLength(0...1))))g"
    }

    private func uniqueMessages(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
