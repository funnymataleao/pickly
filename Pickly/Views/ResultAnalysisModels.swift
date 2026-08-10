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
            return "Good"
        case .medium:
            return "Neutral"
        case .bad:
            return "Watch"
        case .avoid:
            return "Watch"
        case .unknown:
            return "Neutral"
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

extension Product {
    var resultDisplayName: String {
        name == "Unknown product" ? "Product partially recognized" : name
    }

    var resultSubtitle: String {
        name == "Unknown product" ? "Partial product details" : brand
    }

    var resultVerdict: String {
        verdict
    }

    var resultHeadline: String {
        if isLimitedData {
            return "Limited data"
        }

        guard let score else {
            return "Limited data"
        }

        switch score {
        case 85...100:
            return "Great choice"
        case 70..<85:
            return "Good choice"
        case 50..<70:
            return "Okay for occasionally"
        default:
            return "Worth comparing"
        }
    }

    var resultSummary: String {
        if isLimitedData {
            return "We don't have enough nutrition or ingredient data to score this product confidently."
        }

        return summary
    }

    var confidenceText: String {
        "Confidence: \(confidence)"
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
        let sodiumPercent = nutrition.salt100g.map { Int((($0 * 393.4) / 2300 * 100).rounded()) }
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

        return [
            NutritionFact(
                id: "calories",
                title: "Calories",
                value: "Not available",
                percent: nil,
                status: .unknown,
                isKeyFact: true
            ),
            NutritionFact(
                id: "sugar",
                title: sugarLabel.capitalized,
                value: sugarForScoring.map { formattedGrams($0) } ?? "Not available",
                percent: nil,
                status: statusForSugar,
                isKeyFact: true
            ),
            NutritionFact(
                id: "salt",
                title: "Salt / Sodium",
                value: nutrition.salt100g.map { "\(formattedGrams($0)) salt" } ?? "Not available",
                percent: sodiumPercent,
                status: sodiumStatus,
                isKeyFact: true
            ),
            NutritionFact(
                id: "protein",
                title: "Protein",
                value: nutrition.proteins100g.map { formattedGrams($0) } ?? "Not available",
                percent: nil,
                status: statusForProteinFiber,
                isKeyFact: true
            ),
            NutritionFact(
                id: "fat",
                title: "Saturated fat",
                value: nutrition.saturatedFat100g.map { "\(formattedGrams($0)) sat fat" } ?? "Not available",
                percent: nil,
                status: statusForSaturatedFat,
                isKeyFact: true
            ),
            NutritionFact(
                id: "fiber",
                title: "Fiber",
                value: nutrition.fiber100g.map { formattedGrams($0) } ?? "Not available",
                percent: nil,
                status: statusForFiber,
                isKeyFact: false
            )
        ]
    }

    var recommendations: [String] {
        var items: [String] = []

        if let salt = nutrition.salt100g, salt >= 1.0 {
            items.append("Pick lower sodium")
        }

        if let sugar = sugarForScoring, sugar >= 12 {
            items.append("Pick lower sugar")
        }

        if ingredients.count > 12 {
            items.append("Prefer shorter lists")
        }

        if ingredientAnalyses.contains(where: { $0.status == .bad || $0.status == .avoid }) {
            items.append("Prefer fewer additives")
        }

        return Array(items.prefix(3))
    }

    func forYouMessages(preferences: UserPreferences) -> [String] {
        var messages = forYouNotes

        if preferences.lowSugar, let sugar = sugarForScoring, sugar >= 12 {
            messages.append("May not be the best choice if you're reducing sugar")
        }

        if preferences.lowSodium, let salt = nutrition.salt100g, salt >= 1.0 {
            messages.append("You might prefer a lower sodium option")
        }

        if preferences.sensitiveDigestion, ingredients.count > 8 {
            messages.append("Gentler picks usually have shorter ingredient lists")
        }

        if preferences.glutenFree {
            switch dietary.glutenFree {
            case .confirmed:
                break
            case .notSuitable:
                messages.append("May not fit a gluten-free preference")
            case .unknown:
                messages.append("Gluten-free status is not confirmed in the available data")
            }
        }

        if preferences.lactoseFree {
            switch dietary.lactoseFree {
            case .confirmed:
                break
            case .notSuitable:
                messages.append("May not fit a lactose-free preference")
            case .unknown:
                messages.append("Lactose-free status is not confirmed in the available data")
            }
        }

        if preferences.vegan {
            switch dietary.vegan {
            case .confirmed:
                break
            case .notSuitable:
                messages.append("May not fit a vegan preference")
            case .unknown:
                messages.append("Vegan status is not confirmed in the available data")
            }
        }

        if preferences.vegetarian {
            switch dietary.vegetarian {
            case .confirmed:
                break
            case .notSuitable:
                messages.append("May not fit a vegetarian preference")
            case .unknown:
                messages.append("Vegetarian status is not confirmed in the available data")
            }
        }

        if messages.isEmpty {
            messages.append("No personal watch-outs based on your current preferences")
        }

        return Array(uniqueMessages(messages).prefix(3))
    }

    private var sodiumInsight: ProductInsight {
        guard let salt = nutrition.salt100g else {
            return ProductInsight(
                id: "sodium",
                icon: "drop",
                title: "Sodium",
                status: "Limited",
                value: "Not available",
                explanation: "Sodium data is not available.",
                resultStatus: .unknown
            )
        }

        switch salt {
        case ..<0.3:
            return ProductInsight(
                id: "sodium",
                icon: "drop",
                title: "Sodium",
                status: "Low",
                value: "\(formattedGrams(salt)) salt",
                explanation: "Low salt per 100g.",
                resultStatus: .good
            )
        case 0.3..<1.0:
            return ProductInsight(
                id: "sodium",
                icon: "drop",
                title: "Sodium",
                status: "Moderate",
                value: "\(formattedGrams(salt)) salt",
                explanation: "Reasonable, but worth checking serving size.",
                resultStatus: .medium
            )
        default:
            return ProductInsight(
                id: "sodium",
                icon: "drop",
                title: "Sodium",
                status: "High",
                value: "\(formattedGrams(salt)) salt",
                explanation: "Not ideal for daily use if you are limiting sodium.",
                resultStatus: .bad
            )
        }
    }

    private var sugarInsight: ProductInsight {
        guard let sugar = sugarForScoring else {
            return ProductInsight(
                id: "sugar",
                icon: "cube",
                title: "Sugar",
                status: "Limited",
                value: "Not available",
                explanation: "Sugar data is not available yet.",
                resultStatus: .unknown
            )
        }

        switch sugar {
        case ..<5:
            return ProductInsight(
                id: "sugar",
                icon: "cube",
                title: sugarLabel.capitalized,
                status: "Low",
                value: formattedGrams(sugar),
                explanation: "Low \(sugarLabel) per 100g.",
                resultStatus: .good
            )
        case 5..<12:
            return ProductInsight(
                id: "sugar",
                icon: "cube",
                title: sugarLabel.capitalized,
                status: "Moderate",
                value: formattedGrams(sugar),
                explanation: "Moderate \(sugarLabel) level per 100g.",
                resultStatus: .medium
            )
        default:
            return ProductInsight(
                id: "sugar",
                icon: "cube",
                title: sugarLabel.capitalized,
                status: "Higher",
                value: formattedGrams(sugar),
                explanation: "May not be the best everyday choice if reducing sugar.",
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
                title: "Ingredients",
                status: "Limited",
                value: "Not available",
                explanation: "Ingredients are not available yet.",
                resultStatus: .unknown
            )
        }

        if cautionIngredients.isEmpty && ingredients.count <= 8 {
            return ProductInsight(
                id: "ingredients",
                icon: "list.bullet.rectangle",
                title: "Ingredients",
                status: "Simple",
                value: ingredientCountLabel,
                explanation: "Short ingredient list.",
                resultStatus: .good
            )
        }

        if cautionIngredients.isEmpty {
            return ProductInsight(
                id: "ingredients",
                icon: "list.bullet.rectangle",
                title: "Ingredients",
                status: "Mixed",
                value: ingredientCountLabel,
                explanation: "Longer ingredient list than simpler options.",
                resultStatus: .medium
            )
        }

        return ProductInsight(
            id: "ingredients",
            icon: "list.bullet.rectangle",
            title: "Ingredients",
            status: "Watch",
            value: "\(cautionIngredients.count) \(cautionIngredients.count == 1 ? "item" : "items")",
            explanation: "Some ingredients may be worth checking.",
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
                title: "Protein",
                status: "Limited",
                value: "Not available",
                explanation: "Protein and fiber data are incomplete.",
                resultStatus: .unknown
            )
        }

        let value = protein.map { "\(formattedGrams($0)) protein" }
            ?? fiber.map { "\(formattedGrams($0)) fiber" }
            ?? "Not available"

        if (protein ?? 0) >= 10 || (fiber ?? 0) >= 6 {
            return ProductInsight(
                id: "protein-fiber",
                icon: "leaf",
                title: "Protein",
                status: "Helpful",
                value: value,
                explanation: "Adds useful protein or fiber.",
                resultStatus: .good
            )
        }

        return ProductInsight(
            id: "protein-fiber",
            icon: "leaf",
            title: "Protein",
            status: "Modest",
            value: value,
            explanation: "Some nutrition upside, but not a standout.",
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
            return "Adds sweetness and can raise the sugar level."
        }

        if lowercased.contains("salt") || lowercased.contains("sodium") {
            return "Adds flavor and can raise sodium."
        }

        if lowercased.contains("color") || lowercased.contains("colour") || lowercased.contains("caramel") {
            return "Worth watching if you prefer simpler ingredients."
        }

        if lowercased.contains("flavor") || lowercased.contains("preservative") || lowercased.contains("artificial") {
            return "Usually fine, but simpler options may use fewer additives."
        }

        if lowercased.contains("protein") {
            return "Helpful protein source."
        }

        if lowercased.contains("fiber") || lowercased.contains("oat") || lowercased.contains("lentil") {
            return "Simple ingredient that can add fiber."
        }

        if lowercased.contains("milk") || lowercased.contains("cream") {
            return "Dairy ingredient that can add texture and protein."
        }

        if lowercased.contains("water") {
            return "Used as a base ingredient."
        }

        return "Limited details, treated as neutral for now."
    }

    private func formattedGrams(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...1))))g"
    }

    private func uniqueMessages(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
