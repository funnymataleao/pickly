import Foundation

nonisolated enum GroceryGoal: String, CaseIterable, Identifiable, Sendable {
    case all
    case lowSugar
    case lowSodium
    case highProtein
    case shortIngredients
    case vegetarian
    case vegan
    case glutenFree
    case lactoseFree
    case sensitiveDigestion

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: String(localized: "All")
        case .lowSugar: String(localized: "Low sugar")
        case .lowSodium: String(localized: "Low sodium")
        case .highProtein: String(localized: "High protein")
        case .shortIngredients: String(localized: "Short ingredients")
        case .vegetarian: String(localized: "Vegetarian")
        case .vegan: String(localized: "Vegan")
        case .glutenFree: String(localized: "Gluten-free")
        case .lactoseFree: String(localized: "Lactose-free")
        case .sensitiveDigestion: String(localized: "Gentler picks")
        }
    }

    var productSectionTitle: String {
        switch self {
        case .all: String(localized: "Products to check")
        case .lowSugar: String(localized: "Low sugar products")
        case .lowSodium: String(localized: "Low sodium products")
        case .highProtein: String(localized: "High protein products")
        case .shortIngredients: String(localized: "Simple products")
        case .vegetarian: String(localized: "Vegetarian products")
        case .vegan: String(localized: "Vegan products")
        case .glutenFree: String(localized: "Gluten-free products")
        case .lactoseFree: String(localized: "Lactose-free products")
        case .sensitiveDigestion: String(localized: "Gentler products")
        }
    }

    var systemImage: String {
        switch self {
        case .all: "square.grid.2x2.fill"
        case .lowSugar: "cube.transparent.fill"
        case .lowSodium: "droplet.fill"
        case .highProtein: "bolt.heart.fill"
        case .shortIngredients: "list.bullet.rectangle.fill"
        case .vegetarian: "fork.knife.circle.fill"
        case .vegan: "leaf.fill"
        case .glutenFree: "checkmark.shield.fill"
        case .lactoseFree: "cup.and.saucer.fill"
        case .sensitiveDigestion: "feather.fill"
        }
    }

    /// Preference rows and goal chips share the same filled glyph family.
    var preferenceIcon: String {
        systemImage
    }

    var productReason: String {
        // Keep the compact card label aligned with the goal title shown in
        // onboarding, Profile, and the filter chips. A goal tag should never
        // silently switch vocabulary (for example, Low sodium -> Low salt).
        title
    }

    var catalogSearchQuery: String {
        switch self {
        case .all: "groceries"
        case .lowSugar: "no added sugar"
        case .lowSodium: "low salt"
        case .highProtein: "high protein"
        case .shortIngredients: "simple ingredients"
        case .vegetarian: "vegetarian"
        case .vegan: "vegan"
        case .glutenFree: "gluten free"
        case .lactoseFree: "lactose free"
        case .sensitiveDigestion: "plain food"
        }
    }

    /// Open Food Facts uses canonical taxonomy tags for explicit dietary
    /// labels. Keep these separate from the human-readable fallback query: a
    /// text search for "lactose free" is not evidence that a product actually
    /// carries that dietary label.
    var catalogLabelTag: String? {
        switch self {
        case .vegetarian:
            "en:vegetarian"
        case .vegan:
            "en:vegan"
        case .glutenFree:
            "en:no-gluten"
        case .lactoseFree:
            "en:no-lactose"
        case .all, .lowSugar, .lowSodium, .highProtein, .shortIngredients, .sensitiveDigestion:
            nil
        }
    }

    /// Nutrition goals use OFF's nutrient-level taxonomy to retrieve a broad,
    /// structured candidate set. `matches(_:)` remains the final authority and
    /// applies Pickly's exact thresholds to every returned product.
    var catalogNutrientLevelTag: String? {
        switch self {
        case .lowSugar:
            "en:sugars-in-low-quantity"
        case .lowSodium:
            "en:salt-in-low-quantity"
        case .highProtein:
            "en:proteins-in-high-quantity"
        case .sensitiveDigestion:
            "en:saturated-fat-in-low-quantity"
        case .all, .shortIngredients, .vegetarian, .vegan, .glutenFree, .lactoseFree:
            nil
        }
    }

    static func preferred(in preferences: UserPreferences) -> [GroceryGoal] {
        allCases.filter { $0.isPreferred(in: preferences) }
    }

    static func available(in preferences: UserPreferences) -> [GroceryGoal] {
        [.all] + preferred(in: preferences)
    }

    /// Products that match the selected goal filter without duplicates.
    ///
    /// - `all` keeps products that match at least one preferred goal.
    /// - A specific goal keeps only products that match that goal.
    /// - Ranking is by match count (relevance), then score.
    static func matchingProducts(
        in products: [Product],
        filter: GroceryGoal,
        preferredGoals: [GroceryGoal]
    ) -> [Product] {
        let goalsToMatch: [GroceryGoal]
        switch filter {
        case .all:
            goalsToMatch = preferredGoals
        default:
            goalsToMatch = preferredGoals.contains(filter) ? [filter] : []
        }

        guard !goalsToMatch.isEmpty else { return [] }

        var seenProductIDs = Set<String>()

        return products
            .filter { product in
                goalsToMatch.contains { $0.matches(product) }
            }
            .filter { seenProductIDs.insert($0.id).inserted }
            .sorted { lhs, rhs in
                let lhsMatches = preferredGoals.filter { $0.matches(lhs) }.count
                let rhsMatches = preferredGoals.filter { $0.matches(rhs) }.count
                if lhsMatches != rhsMatches {
                    return lhsMatches > rhsMatches
                }
                return (lhs.score ?? -1) > (rhs.score ?? -1)
            }
    }

    /// Goal-matched products ordered for the personalized shelf on Home.
    /// Health score leads the ranking; matching more selected goals breaks ties.
    static func healthiestMatchingProducts(
        in products: [Product],
        filter: GroceryGoal,
        preferredGoals: [GroceryGoal]
    ) -> [Product] {
        matchingProducts(
            in: products,
            filter: filter,
            preferredGoals: preferredGoals
        )
        .sorted { lhs, rhs in
            let lhsScore = lhs.score ?? -1
            let rhsScore = rhs.score ?? -1
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }

            let lhsMatches = preferredGoals.filter { $0.matches(lhs) }.count
            let rhsMatches = preferredGoals.filter { $0.matches(rhs) }.count
            if lhsMatches != rhsMatches {
                return lhsMatches > rhsMatches
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    /// Orders a goal-owned OFF feed by the strength of the selected goal and
    /// then interleaves categories. This keeps Low sugar and Low sodium honest
    /// when a product qualifies for both, while avoiding a Home shelf made of
    /// four near-identical items from one category.
    static func rankedFeedProducts(
        in products: [Product],
        for goal: GroceryGoal
    ) -> [Product] {
        var seenIDs = Set<String>()
        let matching = products
            .filter { goal.matches($0) }
            .filter { seenIDs.insert($0.id).inserted }

        let ranked = matching.enumerated().sorted { lhsEntry, rhsEntry in
            let lhs = lhsEntry.element
            let rhs = rhsEntry.element

            switch goal {
            case .lowSugar:
                let lhsValue = lhs.sugarForScoring ?? .greatestFiniteMagnitude
                let rhsValue = rhs.sugarForScoring ?? .greatestFiniteMagnitude
                if lhsValue != rhsValue { return lhsValue < rhsValue }
            case .lowSodium:
                let lhsValue = lhs.nutrition.salt100g ?? .greatestFiniteMagnitude
                let rhsValue = rhs.nutrition.salt100g ?? .greatestFiniteMagnitude
                if lhsValue != rhsValue { return lhsValue < rhsValue }
            case .highProtein:
                let lhsValue = lhs.nutrition.proteins100g ?? 0
                let rhsValue = rhs.nutrition.proteins100g ?? 0
                if lhsValue != rhsValue { return lhsValue > rhsValue }
            case .shortIngredients:
                if lhs.ingredientCountForMatching != rhs.ingredientCountForMatching {
                    return lhs.ingredientCountForMatching < rhs.ingredientCountForMatching
                }
            case .sensitiveDigestion:
                if lhs.ingredientCountForMatching != rhs.ingredientCountForMatching {
                    return lhs.ingredientCountForMatching < rhs.ingredientCountForMatching
                }
                let lhsValue = lhs.nutrition.saturatedFat100g ?? .greatestFiniteMagnitude
                let rhsValue = rhs.nutrition.saturatedFat100g ?? .greatestFiniteMagnitude
                if lhsValue != rhsValue { return lhsValue < rhsValue }
            case .all, .vegetarian, .vegan, .glutenFree, .lactoseFree:
                break
            }

            let lhsScore = lhs.score ?? -1
            let rhsScore = rhs.score ?? -1
            if lhsScore != rhsScore { return lhsScore > rhsScore }
            return lhsEntry.offset < rhsEntry.offset
        }.map(\.element)

        return interleavingCategories(in: ranked)
    }

    private static func interleavingCategories(in products: [Product]) -> [Product] {
        var bucketIndexes: [String: Int] = [:]
        var buckets: [[Product]] = []

        for product in products {
            let categoryKey = product.category
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if let index = bucketIndexes[categoryKey] {
                buckets[index].append(product)
            } else {
                bucketIndexes[categoryKey] = buckets.count
                buckets.append([product])
            }
        }

        var result: [Product] = []
        var itemIndex = 0
        while result.count < products.count {
            var appended = false
            for bucket in buckets where itemIndex < bucket.count {
                result.append(bucket[itemIndex])
                appended = true
            }
            guard appended else { break }
            itemIndex += 1
        }
        return result
    }

    static func primaryMatch(
        for product: Product,
        filter: GroceryGoal,
        preferredGoals: [GroceryGoal]
    ) -> GroceryGoal? {
        if filter != .all, filter.matches(product) {
            return filter
        }

        let matchingGoals = preferredGoals.filter { $0 != .all && $0.matches(product) }
        guard !matchingGoals.isEmpty else { return nil }

        // `preferredGoals` is derived from the boolean preferences in a
        // stable enum order (Low sugar happens to be first). Returning its
        // first match made every `All` card say Low sugar even when the
        // product was a materially stronger match for another selected goal.
        // Use the verified product facts to choose the most meaningful tag;
        // use onboarding/Profile order only as a deterministic tie-breaker.
        return matchingGoals.max { lhs, rhs in
            let lhsStrength = lhs.matchStrength(for: product)
            let rhsStrength = rhs.matchStrength(for: product)

            if abs(lhsStrength - rhsStrength) > 0.0001 {
                return lhsStrength < rhsStrength
            }

            let lhsIndex = preferredGoals.firstIndex(of: lhs) ?? .max
            let rhsIndex = preferredGoals.firstIndex(of: rhs) ?? .max
            return lhsIndex > rhsIndex
        }
    }

    /// Estimates how strongly a product satisfies a selected goal. This is
    /// only used to choose the compact `All` card tag; it never changes the
    /// actual boolean matching rules above or the product score.
    private func matchStrength(for product: Product) -> Double {
        switch self {
        case .lowSugar:
            guard let value = product.sugarForScoring else { return 0 }
            return max(0, min(1, (5 - value) / 5))
        case .lowSodium:
            guard let value = product.nutrition.salt100g else { return 0 }
            return max(0, min(1, (0.8 - value) / 0.8))
        case .highProtein:
            guard let value = product.nutrition.proteins100g else { return 0 }
            return max(0, min(1, value / 20))
        case .shortIngredients:
            let count = product.ingredientCountForMatching
            guard count > 0 else { return 0 }
            return max(0, min(1, Double(5 - count) / 4))
        case .sensitiveDigestion:
            let ingredientCount = product.ingredientCountForMatching
            let ingredientStrength = ingredientCount > 0
                ? max(0, min(1, Double(5 - ingredientCount) / 4))
                : 0
            let sugarStrength = normalizedStrength(
                product.sugarForScoring,
                threshold: 5,
                lowerIsBetter: true
            )
            let sodiumStrength = normalizedStrength(
                product.nutrition.salt100g,
                threshold: 0.8,
                lowerIsBetter: true
            )
            let saturatedFatStrength = normalizedStrength(
                product.nutrition.saturatedFat100g,
                threshold: 3,
                lowerIsBetter: true
            )
            return min(ingredientStrength, sugarStrength, sodiumStrength, saturatedFatStrength)
        case .vegan:
            return product.dietary.vegan == .confirmed ? 0.70 : 0
        case .vegetarian:
            return product.dietary.vegetarian == .confirmed ? 0.65 : 0
        case .glutenFree:
            return product.dietary.glutenFree == .confirmed ? 0.60 : 0
        case .lactoseFree:
            return product.dietary.lactoseFree == .confirmed ? 0.60 : 0
        case .all:
            return 0
        }
    }

    private func normalizedStrength(
        _ value: Double?,
        threshold: Double,
        lowerIsBetter: Bool
    ) -> Double {
        guard let value, value.isFinite else { return 0 }
        let ratio = value / threshold
        if lowerIsBetter {
            return max(0, min(1, 1 - ratio))
        }
        return max(0, min(1, ratio))
    }

    func matches(_ product: Product) -> Bool {
        switch self {
        case .all:
            return true
        // Dietary labels are independent from the nutrition score. A product
        // may be explicitly lactose-free (or vegan/gluten-free) while still
        // lacking enough nutrition data for a health score.
        case .vegetarian:
            return product.dietary.vegetarian == .confirmed
        case .vegan:
            return product.dietary.vegan == .confirmed
        case .glutenFree:
            return product.dietary.glutenFree == .confirmed
        case .lactoseFree:
            return product.dietary.lactoseFree == .confirmed
        case .lowSugar:
            guard !product.isLimitedData else { return false }
            return (product.sugarForScoring ?? .greatestFiniteMagnitude) <= 5
        case .lowSodium:
            guard !product.isLimitedData else { return false }
            return (product.nutrition.salt100g ?? .greatestFiniteMagnitude) <= 0.8
        case .highProtein:
            guard !product.isLimitedData else { return false }
            return (product.nutrition.proteins100g ?? 0) >= 8
        case .shortIngredients:
            guard !product.isLimitedData else { return false }
            return product.ingredientCountForMatching > 0
                && product.ingredientCountForMatching <= 4
        case .sensitiveDigestion:
            guard !product.isLimitedData else { return false }
            return product.ingredientCountForMatching > 0
                && product.ingredientCountForMatching <= 4
                && (product.sugarForScoring ?? .greatestFiniteMagnitude) <= 5
                && (product.nutrition.salt100g ?? .greatestFiniteMagnitude) <= 0.8
                && (product.nutrition.saturatedFat100g ?? 0) <= 3
        }
    }

    private func isPreferred(in preferences: UserPreferences) -> Bool {
        switch self {
        case .all:
            return false
        case .lowSugar:
            return preferences.lowSugar
        case .lowSodium:
            return preferences.lowSodium
        case .vegetarian:
            return preferences.vegetarian
        case .vegan:
            return preferences.vegan
        case .glutenFree:
            return preferences.glutenFree
        case .lactoseFree:
            return preferences.lactoseFree
        case .sensitiveDigestion:
            return preferences.sensitiveDigestion
        case .highProtein, .shortIngredients:
            return false
        }
    }
}
