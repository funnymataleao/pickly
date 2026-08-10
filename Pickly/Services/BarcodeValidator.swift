import Foundation

nonisolated struct BarcodeValidator: Sendable {
    private static let supportedLengths: Set<Int> = [8, 12, 13, 14]

    static func normalize(_ rawValue: String) -> String? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              value.allSatisfy({ $0 >= "0" && $0 <= "9" }),
              supportedLengths.contains(value.count),
              hasValidCheckDigit(value)
        else {
            return nil
        }

        return value
    }

    private static func hasValidCheckDigit(_ value: String) -> Bool {
        let digits = value.compactMap(\.wholeNumberValue)
        guard digits.count == value.count, let checkDigit = digits.last else {
            return false
        }

        let sum = digits.dropLast().enumerated().reduce(0) { partialResult, item in
            let (index, digit) = item
            let distanceFromRight = digits.count - 2 - index
            let weight = distanceFromRight.isMultiple(of: 2) ? 3 : 1
            return partialResult + digit * weight
        }

        return (10 - (sum % 10)) % 10 == checkDigit
    }
}
