import Foundation

enum ProductSource: String, Codable, Hashable {
    case mock
    case openFoodFacts
    case unknown
}

enum DietaryStatus: String, Codable, Hashable {
    case confirmed
    case notSuitable
    case unknown
}

struct DietaryAttributes: Codable, Hashable {
    var vegetarian: DietaryStatus = .unknown
    var vegan: DietaryStatus = .unknown
    var glutenFree: DietaryStatus = .unknown
    var lactoseFree: DietaryStatus = .unknown

    static let unknown = DietaryAttributes()
}

struct Product: Identifiable, Hashable, Codable {
    struct Nutrition: Hashable, Codable {
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
                addedSugars100g ?? sugars100g,
                salt100g,
                saturatedFat100g,
                proteins100g,
                fiber100g
            ].compactMap { $0 }.count
        }

        var isIncomplete: Bool {
            knownFieldCount <= 1
        }
    }

    let id: String
    let barcode: String
    let name: String
    let brand: String
    let category: String
    let imageName: String
    let imageURL: URL?
    let ingredients: [String]
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
        case imageName
        case imageURL
        case ingredients
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
        self.imageName = try container.decode(String.self, forKey: .imageName)
        self.imageURL = try container.decodeIfPresent(URL.self, forKey: .imageURL)
        self.ingredients = try container.decode([String].self, forKey: .ingredients)
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
        imageName: String,
        imageURL: URL? = nil,
        ingredients: [String],
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
        self.imageName = imageName
        self.imageURL = imageURL
        self.ingredients = ingredients
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
        nutrition.addedSugars100g ?? nutrition.sugars100g
    }

    var sugarLabel: String {
        nutrition.addedSugars100g == nil ? "sugar" : "added sugar"
    }

    var ingredientCountLabel: String {
        let noun = ingredients.count == 1 ? "item" : "items"
        return "\(ingredients.count) \(noun)"
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
}
