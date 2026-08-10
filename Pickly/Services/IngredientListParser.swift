import Foundation

nonisolated struct IngredientListParser: Sendable {
    nonisolated init() {}

    func parse(_ text: String) -> [String] {
        var ingredients: [String] = []
        var current = ""
        var nestingDepth = 0

        for character in text {
            switch character {
            case "(", "[", "{":
                nestingDepth += 1
                current.append(character)
            case ")", "]", "}":
                nestingDepth = max(0, nestingDepth - 1)
                current.append(character)
            case ",", ";":
                if nestingDepth == 0 {
                    append(current, to: &ingredients)
                    current = ""
                } else {
                    current.append(character)
                }
            default:
                current.append(character)
            }
        }

        append(current, to: &ingredients)
        return ingredients
    }

    private func append(_ value: String, to ingredients: inout [String]) {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        ingredients.append(cleaned)
    }
}
