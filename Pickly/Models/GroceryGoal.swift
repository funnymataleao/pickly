import Foundation

enum GroceryGoal: String, CaseIterable, Identifiable {
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
        case .sensitiveDigestion: "Sensitive digestion"
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
        case .lowSodium: "drop"
        case .highProtein: "bolt.heart"
        case .shortIngredients: "list.bullet.rectangle"
        case .vegetarian: "carrot"
        case .vegan: "leaf"
        case .glutenFree: "checkmark.seal"
        case .lactoseFree: "cup.and.saucer"
        case .sensitiveDigestion: "heart.text.square"
        }
    }

    var productReason: String {
        switch self {
        case .all: "All"
        case .lowSugar: "Low sugar"
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

    static func preferred(in preferences: UserPreferences) -> [GroceryGoal] {
        allCases.filter { $0.isPreferred(in: preferences) }
    }

    static func available(in preferences: UserPreferences) -> [GroceryGoal] {
        [.all] + preferred(in: preferences)
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
