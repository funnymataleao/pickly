import Foundation

struct ScoringService {
    nonisolated init() {}

    struct Result {
        let score: Int?
        let summary: String
        let reasons: [String]
        let warnings: [String]
        let positives: [String]
        let forYouNotes: [String]
        let confidence: String
        let nutritionSummary: String
    }

    func evaluate(
        nutrition: Product.Nutrition,
        ingredients: [String],
        additivesTags: [String],
        hasProductName: Bool = true
    ) -> Result {
        if !hasProductName || nutrition.isIncomplete {
            return limitedDataResult(
                nutrition: nutrition,
                ingredients: ingredients,
                hasProductName: hasProductName
            )
        }

        var score = 75
        var reasons: [String] = []
        var warnings: [String] = []
        var positives: [String] = []
        var forYouNotes: [String] = []

        if let sugars = nutrition.addedSugars100g ?? nutrition.sugars100g {
            let sugarLabel = nutrition.addedSugars100g == nil ? "sugar" : "added sugar"

            switch sugars {
            case ..<5:
                score += 3
                positives.append("Low in \(sugarLabel) per 100g")
            case 5..<12:
                reasons.append("Moderate \(sugarLabel) level per 100g")
            case 12..<22:
                score -= 10
                warnings.append("Contains more \(sugarLabel) than ideal for everyday use")
                forYouNotes.append("May not be the best choice if you're reducing sugar")
            default:
                score -= 18
                warnings.append("High \(sugarLabel) level per 100g")
                forYouNotes.append("You might prefer a lower sugar option")
            }

            if nutrition.addedSugars100g == nil {
                reasons.append("Added sugar data is not available, so this uses total sugar")
            }
        }

        if let salt = nutrition.salt100g {
            switch salt {
            case ..<0.3:
                score += 3
                positives.append("Low salt per 100g")
            case 0.3..<1.0:
                reasons.append("Moderate sodium level per 100g")
            case 1.0..<1.5:
                score -= 10
                warnings.append("Salt is higher than ideal for everyday use")
            default:
                score -= 16
                warnings.append("High sodium level per 100g")
                forYouNotes.append("You might prefer a lower sodium option")
            }
        }

        if let saturatedFat = nutrition.saturatedFat100g {
            switch saturatedFat {
            case ..<1.5:
                score += 2
                positives.append("Low saturated fat per 100g")
            case 1.5..<5:
                reasons.append("Moderate saturated fat level")
            case 5..<10:
                score -= 10
                warnings.append("Saturated fat is higher than ideal for everyday use")
            default:
                score -= 16
                warnings.append("High saturated fat level per 100g")
            }
        }

        if let proteins = nutrition.proteins100g {
            if proteins >= 10 {
                score += 5
                positives.append("Good source of protein")
            } else if proteins >= 5 {
                score += 2
                positives.append("Contains some protein")
            }
        }

        if let fiber = nutrition.fiber100g {
            if fiber >= 6 {
                score += 5
                positives.append("Good source of fiber")
            } else if fiber >= 3 {
                score += 2
                positives.append("Contains some fiber")
            }
        }

        if ingredients.isEmpty {
            warnings.append("Ingredient data is not available yet")
        } else if ingredients.count > 20 {
            score -= 8
            warnings.append("Ingredient list has more than 20 items")
        } else if ingredients.count > 12 {
            score -= 5
            warnings.append("Ingredient list has more than 12 items")
        } else {
            reasons.append("Ingredient list is reasonably short")
        }

        if additivesTags.count > 4 {
            score -= 5
            warnings.append("Contains several listed additives")
        } else if !additivesTags.isEmpty {
            score -= 2
            reasons.append("Contains a small number of listed additives")
        }

        let confidence = confidenceLevel(
            nutrition: nutrition,
            hasIngredients: !ingredients.isEmpty
        )

        if confidence != "High" {
            warnings.append("Nutrition data is incomplete, so confidence is lower")
        }

        let finalScore = min(100, max(0, score))
        let summary = summary(for: finalScore, confidence: confidence)

        return Result(
            score: finalScore,
            summary: summary,
            reasons: unique(reasons.isEmpty ? ["Score is based on the available nutrition and ingredient data"] : reasons),
            warnings: unique(warnings.isEmpty ? ["No major watch-outs in the available data"] : warnings),
            positives: unique(positives),
            forYouNotes: unique(forYouNotes),
            confidence: confidence,
            nutritionSummary: nutritionSummary(for: nutrition)
        )
    }

    private func limitedDataResult(
        nutrition: Product.Nutrition,
        ingredients: [String],
        hasProductName: Bool
    ) -> Result {
        var warnings: [String] = []

        if !hasProductName {
            warnings.append("Product name is not available yet.")
        }

        if ingredients.isEmpty {
            warnings.append("Ingredients not available yet.")
        }

        if nutrition.isIncomplete {
            warnings.append("Nutrition facts are incomplete.")
        }

        return Result(
            score: nil,
            summary: "Some product details are missing.",
            reasons: ["Not enough nutrition data for a reliable score."],
            warnings: unique(warnings.isEmpty ? ["Product details are incomplete."] : warnings),
            positives: [],
            forYouNotes: [],
            confidence: "Low",
            nutritionSummary: nutritionSummary(for: nutrition)
        )
    }

    private func confidenceLevel(
        nutrition: Product.Nutrition,
        hasIngredients: Bool
    ) -> String {
        let knownNutritionFields = nutrition.knownFieldCount

        if knownNutritionFields >= 4 && hasIngredients {
            return "High"
        }

        if knownNutritionFields >= 2 {
            return "Medium"
        }

        return "Low"
    }

    private func summary(for score: Int, confidence: String) -> String {
        if confidence == "Low" {
            return "Pickly found this product, but nutrition data is limited, so the score is less certain."
        }

        switch score {
        case 85...100:
            return "A strong option based on the available nutrition and ingredient data."
        case 70..<85:
            return "A balanced option with a few details worth checking."
        case 50..<70:
            return "An okay option, though some nutrition details may make it better as an occasional choice."
        default:
            return "Better as an occasional option based on the available nutrition details."
        }
    }

    private func nutritionSummary(for nutrition: Product.Nutrition) -> String {
        let values = [
            format(
                nutrition.addedSugars100g ?? nutrition.sugars100g,
                label: nutrition.addedSugars100g == nil ? "sugar" : "added sugar"
            ),
            format(nutrition.salt100g, label: "salt"),
            format(nutrition.saturatedFat100g, label: "sat fat"),
            format(nutrition.proteins100g, label: "protein"),
            format(nutrition.fiber100g, label: "fiber")
        ].compactMap { $0 }

        guard !values.isEmpty else {
            return "Nutrition data incomplete"
        }

        return values.joined(separator: ", ")
    }

    private func format(_ value: Double?, label: String) -> String? {
        guard let value else {
            return nil
        }

        return "\(value.formatted(.number.precision(.fractionLength(0...1))))g \(label)"
    }

    private func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
