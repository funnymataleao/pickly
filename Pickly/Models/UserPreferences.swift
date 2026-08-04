import Foundation

struct UserPreferences: Hashable, Codable {
    var sensitiveDigestion: Bool
    var lowSugar: Bool
    var lowSodium: Bool
    var vegetarian: Bool
    var vegan: Bool
    var glutenFree: Bool
    var lactoseFree: Bool

    static let prototype = UserPreferences(
        sensitiveDigestion: false,
        lowSugar: false,
        lowSodium: false,
        vegetarian: false,
        vegan: false,
        glutenFree: false,
        lactoseFree: false
    )
}
