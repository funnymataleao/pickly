import Foundation

nonisolated enum ProductSource: String, Codable, Hashable, Sendable {
    case mock
    case openFoodFacts
    case unknown
}

nonisolated enum DietaryStatus: String, Codable, Hashable, Sendable {
    case confirmed
    case notSuitable
    case unknown
}

nonisolated struct DietaryAttributes: Codable, Hashable, Sendable {
    var vegetarian: DietaryStatus = .unknown
    var vegan: DietaryStatus = .unknown
    var glutenFree: DietaryStatus = .unknown
    var lactoseFree: DietaryStatus = .unknown

    static let unknown = DietaryAttributes()
}

nonisolated struct Product: Identifiable, Hashable, Codable, Sendable {
    struct SugarAssessment: Hashable, Sendable {
        let value: Double?
        let label: String
        let explanation: String?
        let hasDataConflict: Bool
    }

    struct Nutrition: Hashable, Codable, Sendable {
        var sugars100g: Double?
        var addedSugars100g: Double?
        var salt100g: Double?
        var saturatedFat100g: Double?
        var proteins100g: Double?
        var fiber100g: Double?

        init(
            sugars100g: Double? = nil,
            addedSugars100g: Double? = nil,
            salt100g: Double? = nil,
            saturatedFat100g: Double? = nil,
            proteins100g: Double? = nil,
            fiber100g: Double? = nil
        ) {
            self.sugars100g = sugars100g
            self.addedSugars100g = addedSugars100g
            self.salt100g = salt100g
            self.saturatedFat100g = saturatedFat100g
            self.proteins100g = proteins100g
            self.fiber100g = fiber100g
        }

        private enum CodingKeys: String, CodingKey {
            case sugars100g
            case addedSugars100g
            case salt100g
            case saturatedFat100g
            case proteins100g
            case fiber100g
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                sugars100g: try container.decodeIfPresent(Double.self, forKey: .sugars100g),
                addedSugars100g: try container.decodeIfPresent(Double.self, forKey: .addedSugars100g),
                salt100g: try container.decodeIfPresent(Double.self, forKey: .salt100g),
                saturatedFat100g: try container.decodeIfPresent(Double.self, forKey: .saturatedFat100g),
                proteins100g: try container.decodeIfPresent(Double.self, forKey: .proteins100g),
                fiber100g: try container.decodeIfPresent(Double.self, forKey: .fiber100g)
            )
        }

        static let empty = Nutrition()

        var knownFieldCount: Int {
            [
                Self.plausible(addedSugars100g) ?? Self.plausible(sugars100g),
                Self.plausible(salt100g),
                Self.plausible(saturatedFat100g),
                Self.plausible(proteins100g),
                Self.plausible(fiber100g)
            ].compactMap { $0 }.count
        }

        var isIncomplete: Bool {
            let hasSugar = Self.plausible(addedSugars100g) != nil
                || Self.plausible(sugars100g) != nil
            let hasSalt = Self.plausible(salt100g) != nil
            let hasSaturatedFat = Self.plausible(saturatedFat100g) != nil

            // A score must have the core negative nutrition fields. Protein and
            // fiber can improve a complete result, but cannot establish a safe
            // baseline when sugar, salt, or saturated fat is unknown.
            return !(hasSugar && hasSalt && hasSaturatedFat)
        }

        func sugarAssessment(ingredients: [String]) -> SugarAssessment {
            let totalSugar = Self.plausible(sugars100g)
            let addedSugar = Self.plausible(addedSugars100g)
            let addedSugarExceedsTotal = addedSugar.map { added in
                totalSugar.map { added > $0 + 0.1 } ?? false
            } ?? false
            let zeroAddedSugarConflictsWithIngredients = addedSugar == 0
                && (totalSugar ?? 0) > 1
                && Self.containsAddedSweetener(in: ingredients)
            let rawAddedSugarIsInvalid = addedSugars100g != nil && addedSugar == nil
            let hasConflict = rawAddedSugarIsInvalid
                || addedSugarExceedsTotal
                || zeroAddedSugarConflictsWithIngredients

            if let addedSugar, !hasConflict {
                return SugarAssessment(
                    value: addedSugar,
                    label: "added sugar",
                    explanation: nil,
                    hasDataConflict: false
                )
            }

            if let totalSugar {
                return SugarAssessment(
                    value: totalSugar,
                    label: "sugar",
                    explanation: hasConflict
                        ? "Added sugar data looks inconsistent, so this uses total sugar"
                        : "Added sugar data is not available, so this uses total sugar",
                    hasDataConflict: hasConflict
                )
            }

            return SugarAssessment(
                value: nil,
                label: "sugar",
                explanation: hasConflict
                    ? "Added sugar data looks inconsistent and total sugar is unavailable"
                    : nil,
                hasDataConflict: hasConflict
            )
        }

        private static func plausible(_ value: Double?) -> Double? {
            guard let value, value.isFinite, (0...100).contains(value) else {
                return nil
            }

            return value
        }

        private static func containsAddedSweetener(in ingredients: [String]) -> Bool {
            let sweetenerTerms = [
                "sugar", "sucre", "sucrose", "saccharose", "syrup", "sirup",
                "glucose", "fructose", "dextrose", "maltose", "honey", "molasses",
                "agave", "corn sweetener", "sweetened condensed",
                "zucker", "honig", "melasse", "glukose", "fruktose", "süß",
                "zucchero", "sciroppo", "miele", "melassa", "dolcificat",
                "azúcar", "jarabe", "miel", "melaza", "endulzad",
                "açúcar", "xarope", "mel", "melaço", "adoçad",
                "sukker", "honning", "sødet",
                "cukier", "syrop", "miód", "słodzon",
                "cukr", "med", "slazen"
            ]

            return ingredients.contains { ingredient in
                let normalized = ingredient
                    .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
                    .lowercased()
                let tokens = Set(
                    normalized
                        .components(separatedBy: CharacterSet.alphanumerics.inverted)
                        .filter { !$0.isEmpty }
                )

                return sweetenerTerms.contains { rawTerm in
                    let term = rawTerm
                        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
                        .lowercased()
                    return term.contains(" ") ? normalized.contains(term) : tokens.contains(term)
                }
            }
        }
    }

    let id: String
    let barcode: String
    let name: String
    let brand: String
    let category: String
    let categoryTags: [String]
    let imageName: String
    let imageURL: URL?
    let ingredients: [String]
    let declaredIngredientCount: Int?
    let nutrition: Nutrition
    let nutritionSummary: String
    let score: Int?
    let summary: String
    let reasons: [String]
    let warnings: [String]
    let positives: [String]
    let forYouNotes: [String]
    let alternativeIDs: [String]
    let confidence: String
    let dietary: DietaryAttributes
    let source: ProductSource

    private enum CodingKeys: String, CodingKey {
        case id
        case barcode
        case name
        case brand
        case category
        case categoryTags
        case imageName
        case imageURL
        case ingredients
        case declaredIngredientCount
        case nutrition
        case nutritionSummary
        case score
        case summary
        case reasons
        case warnings
        case positives
        case forYouNotes
        case alternativeIDs
        case confidence
        case dietary
        case source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.barcode = try container.decode(String.self, forKey: .barcode)
        self.name = try container.decode(String.self, forKey: .name)
        self.brand = try container.decode(String.self, forKey: .brand)
        self.category = try container.decode(String.self, forKey: .category)
        self.categoryTags = try container.decodeIfPresent([String].self, forKey: .categoryTags) ?? []
        self.imageName = try container.decode(String.self, forKey: .imageName)
        self.imageURL = try container.decodeIfPresent(URL.self, forKey: .imageURL)
        self.ingredients = try container.decode([String].self, forKey: .ingredients)
        self.declaredIngredientCount = try container.decodeIfPresent(Int.self, forKey: .declaredIngredientCount)
        self.nutrition = try container.decode(Nutrition.self, forKey: .nutrition)
        self.nutritionSummary = try container.decode(String.self, forKey: .nutritionSummary)
        self.score = try container.decodeIfPresent(Int.self, forKey: .score)
        self.summary = try container.decode(String.self, forKey: .summary)
        self.reasons = try container.decode([String].self, forKey: .reasons)
        self.warnings = try container.decode([String].self, forKey: .warnings)
        self.positives = try container.decode([String].self, forKey: .positives)
        self.forYouNotes = try container.decode([String].self, forKey: .forYouNotes)
        self.alternativeIDs = try container.decode([String].self, forKey: .alternativeIDs)
        self.confidence = try container.decode(String.self, forKey: .confidence)
        self.dietary = try container.decodeIfPresent(DietaryAttributes.self, forKey: .dietary) ?? .unknown
        self.source = try container.decodeIfPresent(ProductSource.self, forKey: .source) ?? .unknown
    }

    init(
        id: String,
        barcode: String,
        name: String,
        brand: String,
        category: String,
        categoryTags: [String] = [],
        imageName: String,
        imageURL: URL? = nil,
        ingredients: [String],
        declaredIngredientCount: Int? = nil,
        nutrition: Nutrition,
        nutritionSummary: String,
        score: Int?,
        summary: String,
        reasons: [String],
        warnings: [String],
        positives: [String],
        forYouNotes: [String],
        alternativeIDs: [String],
        confidence: String,
        dietary: DietaryAttributes = .unknown,
        source: ProductSource = .unknown
    ) {
        self.id = id
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.category = category
        self.categoryTags = categoryTags
        self.imageName = imageName
        self.imageURL = imageURL
        self.ingredients = ingredients
        self.declaredIngredientCount = declaredIngredientCount
        self.nutrition = nutrition
        self.nutritionSummary = nutritionSummary
        self.score = score
        self.summary = summary
        self.reasons = reasons
        self.warnings = warnings
        self.positives = positives
        self.forYouNotes = forYouNotes
        self.alternativeIDs = alternativeIDs
        self.confidence = confidence
        self.dietary = dietary
        self.source = source
    }

    var isLimitedData: Bool {
        score == nil || confidence == "Low"
    }

    var isSampleData: Bool {
        source == .mock
    }

    var sugarForScoring: Double? {
        nutrition.sugarAssessment(ingredients: ingredients).value
    }

    var sugarLabel: String {
        nutrition.sugarAssessment(ingredients: ingredients).label
    }

    func replacingID(with newID: String) -> Product {
        Product(
            id: newID,
            barcode: barcode,
            name: name,
            brand: brand,
            category: category,
            categoryTags: categoryTags,
            imageName: imageName,
            imageURL: imageURL,
            ingredients: ingredients,
            declaredIngredientCount: declaredIngredientCount,
            nutrition: nutrition,
            nutritionSummary: nutritionSummary,
            score: score,
            summary: summary,
            reasons: reasons,
            warnings: warnings,
            positives: positives,
            forYouNotes: forYouNotes,
            alternativeIDs: alternativeIDs,
            confidence: confidence,
            dietary: dietary,
            source: source
        )
    }

    func replacingName(with newName: String) -> Product {
        Product(
            id: id,
            barcode: barcode,
            name: newName,
            brand: brand,
            category: category,
            categoryTags: categoryTags,
            imageName: imageName,
            imageURL: imageURL,
            ingredients: ingredients,
            declaredIngredientCount: declaredIngredientCount,
            nutrition: nutrition,
            nutritionSummary: nutritionSummary,
            score: score,
            summary: summary,
            reasons: reasons,
            warnings: warnings,
            positives: positives,
            forYouNotes: forYouNotes,
            alternativeIDs: alternativeIDs,
            confidence: confidence,
            dietary: dietary,
            source: source
        )
    }

    /// Combines the shared catalog record with a fresh OFF record without
    /// allowing either source to erase the other's stronger facts.
    func mergingCatalogData(from incoming: Product) -> Product {
        let existingIsCurated = isCuratedCatalogRecord
        let incomingIsCurated = incoming.isCuratedCatalogRecord
        let scoringProduct = incomingIsCurated || !existingIsCurated ? incoming : self
        let descriptiveProduct = existingIsCurated && !incomingIsCurated ? self : incoming
        let mergedNutrition = Nutrition(
            sugars100g: incoming.nutrition.sugars100g ?? nutrition.sugars100g,
            addedSugars100g: incoming.nutrition.addedSugars100g ?? nutrition.addedSugars100g,
            salt100g: incoming.nutrition.salt100g ?? nutrition.salt100g,
            saturatedFat100g: incoming.nutrition.saturatedFat100g ?? nutrition.saturatedFat100g,
            proteins100g: incoming.nutrition.proteins100g ?? nutrition.proteins100g,
            fiber100g: incoming.nutrition.fiber100g ?? nutrition.fiber100g
        )
        let mergedDietary = DietaryAttributes(
            vegetarian: Self.mergedDietaryStatus(dietary.vegetarian, incoming.dietary.vegetarian),
            vegan: Self.mergedDietaryStatus(dietary.vegan, incoming.dietary.vegan),
            glutenFree: Self.mergedDietaryStatus(dietary.glutenFree, incoming.dietary.glutenFree),
            lactoseFree: Self.mergedDietaryStatus(dietary.lactoseFree, incoming.dietary.lactoseFree)
        )
        var seenAlternativeIDs = Set<String>()
        let mergedAlternativeIDs = (alternativeIDs + incoming.alternativeIDs)
            .filter { seenAlternativeIDs.insert($0).inserted }
        var seenCategoryTags = Set<String>()
        let mergedCategoryTags = (categoryTags + incoming.categoryTags)
            .filter { seenCategoryTags.insert($0.lowercased()).inserted }

        return Product(
            id: id,
            barcode: barcode,
            name: descriptiveProduct.name == "Unknown product" ? name : descriptiveProduct.name,
            brand: descriptiveProduct.brand == "Unknown brand" ? brand : descriptiveProduct.brand,
            category: descriptiveProduct.category == "Grocery" ? category : descriptiveProduct.category,
            categoryTags: mergedCategoryTags,
            imageName: descriptiveProduct.imageName,
            imageURL: incoming.imageURL ?? imageURL,
            ingredients: incoming.ingredients.isEmpty ? ingredients : incoming.ingredients,
            declaredIngredientCount: incoming.declaredIngredientCount ?? declaredIngredientCount,
            nutrition: mergedNutrition,
            nutritionSummary: scoringProduct.nutritionSummary,
            score: scoringProduct.score,
            summary: scoringProduct.summary,
            reasons: scoringProduct.reasons,
            warnings: scoringProduct.warnings,
            positives: scoringProduct.positives,
            forYouNotes: scoringProduct.forYouNotes,
            alternativeIDs: mergedAlternativeIDs,
            confidence: scoringProduct.confidence,
            dietary: mergedDietary,
            source: scoringProduct.source
        )
    }

    private var isCuratedCatalogRecord: Bool {
        source != .mock && !id.hasPrefix("off-")
    }

    private static func mergedDietaryStatus(
        _ current: DietaryStatus,
        _ incoming: DietaryStatus
    ) -> DietaryStatus {
        if current == .notSuitable || incoming == .notSuitable {
            return .notSuitable
        }
        if current == .confirmed || incoming == .confirmed {
            return .confirmed
        }
        return .unknown
    }

    var ingredientCountLabel: String {
        let count = ingredientCountForMatching
        let noun = count == 1
            ? PicklyCopy.localized("item")
            : PicklyCopy.localized("items")
        return "\(count) \(noun)"
    }

    var ingredientCountForMatching: Int {
        declaredIngredientCount ?? ingredients.count
    }

    var verdict: String {
        guard !isLimitedData, let score else {
            return "Limited data"
        }

        switch score {
        case 85...100:
            return "Great"
        case 70..<85:
            return "Good"
        case 50..<70:
            return "Okay"
        default:
            return "Not great"
        }
    }

    /// Localized display value for the stable English verdict enum.
    /// Keep `verdict` English because matching, persistence, and analytics use
    /// it as a semantic value rather than presentation text.
    var localizedVerdict: String {
        PicklyCopy.localized(verdict)
    }

    var displayBrandName: String {
        brand == "Unknown brand" ? PicklyCopy.localized("Unknown brand") : brand
    }

    /// Rebuilds human-readable analysis in the selected app language while
    /// preserving the catalog's numeric score and verified product facts.
    func localizedPresentation(
        localeContext: PicklyLocaleContext = .current
    ) -> Product {
        let locale = Locale(identifier: localeContext.language.localeIdentifier)
        let localizedNutritionSummary: String
        if localeContext.language == .en {
            localizedNutritionSummary = nutritionSummary
        } else {
            // Nutrition summaries are assembled from verified numeric facts,
            // so regenerate only their labels for the selected locale. The
            // persisted score and the source facts are never recalculated.
            localizedNutritionSummary = ScoringService(localeContext: localeContext)
                .evaluate(
                    nutrition: nutrition,
                    ingredients: ingredients,
                    additivesTags: [],
                    hasProductName: name != "Unknown product",
                    category: category
                )
                .nutritionSummary
        }

        return replacingAnalysis(
            nutritionSummary: localizedNutritionSummary,
            summary: PicklyCopy.localized(summary, locale: locale),
            reasons: reasons.map { PicklyCopy.localized($0, locale: locale) },
            warnings: warnings.map { PicklyCopy.localized($0, locale: locale) },
            positives: positives.map { PicklyCopy.localized($0, locale: locale) },
            forYouNotes: forYouNotes.map { PicklyCopy.localized($0, locale: locale) },
            confidence: confidence
        )
    }

    func replacingAnalysis(
        nutritionSummary: String,
        summary: String,
        reasons: [String],
        warnings: [String],
        positives: [String],
        forYouNotes: [String],
        confidence: String
    ) -> Product {
        Product(
            id: id,
            barcode: barcode,
            name: name,
            brand: brand,
            category: category,
            categoryTags: categoryTags,
            imageName: imageName,
            imageURL: imageURL,
            ingredients: ingredients,
            declaredIngredientCount: declaredIngredientCount,
            nutrition: nutrition,
            nutritionSummary: nutritionSummary,
            score: score,
            summary: summary,
            reasons: reasons,
            warnings: warnings,
            positives: positives,
            forYouNotes: forYouNotes,
            alternativeIDs: alternativeIDs,
            confidence: confidence,
            dietary: dietary,
            source: source
        )
    }
}
