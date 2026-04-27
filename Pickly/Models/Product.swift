import Foundation

struct Product: Identifiable, Hashable {
    let id: String
    let barcode: String
    let name: String
    let brand: String
    let category: String
    let imageName: String
    let ingredients: [String]
    let nutritionSummary: String
    let score: Int
    let summary: String
    let reasons: [String]
    let warnings: [String]
    let positives: [String]
    let forYouNotes: [String]
    let alternativeIDs: [String]
    let confidence: String

    var verdict: String {
        switch score {
        case 85...100:
            "Great"
        case 70..<85:
            "Good"
        case 50..<70:
            "Okay"
        default:
            "Not great"
        }
    }
}
