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
        case .all: "All"
        case .lowSugar: "Low sugar"
        case .lowSodium: "Low sodium"
        case .highProtein: "High protein"
        case .shortIngredients: "Short ingredients"
        case .vegetarian: "Vegetarian"
        case .vegan: "Vegan"
        case .glutenFree: "Gluten-free"
        case .lactoseFree: "Lactose-free"
        case .sensitiveDigestion: "Gentler picks"
        }
    }

    var productSectionTitle: String {
        switch self {
        case .all: "Products to check"
        case .lowSugar: "Low sugar products"
        case .lowSodium: "Low sodium products"
        case .highProtein: "High protein products"
        case .shortIngredients: "Simple products"
        case .vegetarian: "Vegetarian products"
        case .vegan: "Vegan products"
        case .glutenFree: "Gluten-free products"
        case .lactoseFree: "Lactose-free products"
        case .sensitiveDigestion: "Gentler products"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "square.grid.2x2"
        case .lowSugar: "cube.transparent"
        case .lowSodium: "droplet"
        case .highProtein: "bolt.heart"
        case .shortIngredients: "list.bullet.rectangle"
        case .vegetarian: "fork.knife.circle"
        case .vegan: "leaf"
        case .glutenFree: "checkmark.shield"
        case .lactoseFree: "cup.and.saucer"
        case .sensitiveDigestion: "feather"
        }
    }

    /// A stronger filled glyph for preference rows. Goal filter chips keep
    /// the quieter outline variant from `systemImage`.
    var preferenceIcon: String {
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

    var productReason: String {
        switch self {
        case .all: "All"
        case .lowSugar: "Low added sugar"
        case .lowSodium: "Lower salt"
        case .highProtein: "Good protein"
        case .shortIngredients: "Short ingredients"
        case .vegetarian: "Vegetarian"
        case .vegan: "Vegan"
        case .glutenFree: "Gluten-free"
        case .lactoseFree: "Lactose-free"
        case .sensitiveDigestion: "Gentler pick"
        }
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

    static func primaryMatch(
        for product: Product,
        filter: GroceryGoal,
        preferredGoals: [GroceryGoal]
    ) -> GroceryGoal? {
        if filter != .all, filter.matches(product) {
            return filter
        }

        return preferredGoals.first { $0.matches(product) }
    }

    func matches(_ product: Product) -> Bool {
        guard self != .all else { return true }

        if product.isLimitedData {
            return false
        }

        switch self {
        case .all:
            return true
        case .lowSugar:
            return (product.sugarForScoring ?? .greatestFiniteMagnitude) <= 5
        case .lowSodium:
            return (product.nutrition.salt100g ?? .greatestFiniteMagnitude) <= 0.8
        case .highProtein:
            return (product.nutrition.proteins100g ?? 0) >= 8
        case .shortIngredients:
            return !product.ingredients.isEmpty && product.ingredients.count <= 4
        case .vegetarian:
            return product.dietary.vegetarian == .confirmed
        case .vegan:
            return product.dietary.vegan == .confirmed
        case .glutenFree:
            return product.dietary.glutenFree == .confirmed
        case .lactoseFree:
            return product.dietary.lactoseFree == .confirmed
        case .sensitiveDigestion:
            return !product.ingredients.isEmpty
                && product.ingredients.count <= 8
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
