import Foundation

struct UserPreferences: Hashable {
    var sensitiveDigestion: Bool
    var lowSugar: Bool
    var lowSodium: Bool
    var vegetarian: Bool
    var vegan: Bool
    var glutenFree: Bool
    var lactoseFree: Bool

    static let prototype = UserPreferences(
        sensitiveDigestion: true,
        lowSugar: true,
        lowSodium: false,
        vegetarian: false,
        vegan: false,
        glutenFree: false,
        lactoseFree: false
    )
}
