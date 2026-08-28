import Foundation

nonisolated enum ScoringMethodology {
    static let baselineScore = 75

    static let scorePurpose: LocalizedStringResource = "Pickly gives grocery products a 0–100 score using the nutrition and ingredient data available for that product. The score helps compare grocery options; it is not a safety rating."

    static let calculation: LocalizedStringResource = "A complete result starts at 75. Higher sugar, salt, saturated fat, longer ingredient lists, and listed additives can lower the score. Lower levels of those nutrients, plus protein and fiber, can raise it. Beverage sugar uses stricter thresholds."

    static let verdictRanges: LocalizedStringResource = "Verdicts use fixed ranges: Great 85–100, Good 70–84, Okay 50–69, and Not great 0–49."

    static let dataSources: LocalizedStringResource = "Scores use the product data currently available from Pickly's catalog and Open Food Facts. Pickly does not independently laboratory-test products, and recipes or labels can change."

    static let confidence: LocalizedStringResource = "Confidence reflects how complete and consistent the available nutrition and ingredient data is. If sugar, salt, or saturated fat is missing, Pickly shows Limited data instead of a numeric score."

    static let medicalDisclaimer: LocalizedStringResource = "Pickly provides general grocery information, not medical advice. It does not diagnose, treat, cure, or prevent any disease. Check the package label for allergens and dietary needs, and consult a qualified healthcare professional before making medical decisions."
}
