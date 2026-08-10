import Foundation

nonisolated struct SupabaseProductService: Sendable {
    enum ServiceError: LocalizedError {
        case notConfigured
        case invalidURL
        case invalidResponse
        case requestFailed
        case decoding(Error)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                "Product catalog is not configured yet."
            case .invalidURL:
                "The product catalog request could not be created."
            case .invalidResponse, .decoding:
                "The product catalog returned an unexpected response."
            case .requestFailed:
                "The product catalog is unavailable right now."
            }
        }
    }

    private let session: URLSession
    init(session: URLSession = .shared) {
        self.session = session
    }

    var isConfigured: Bool {
        SupabaseCredentials.isConfigured
    }

    func fetchPublishedProducts(limit: Int = 60) async throws -> [Product] {
        let data = try await request(
            path: "rest/v1/products",
            query: [
                URLQueryItem(name: "select", value: ProductRow.selectFields),
                URLQueryItem(name: "is_published", value: "eq.true"),
                URLQueryItem(name: "order", value: "updated_at.desc"),
                URLQueryItem(name: "limit", value: String(max(1, min(limit, 100))))
            ]
        )

        do {
            return try JSONDecoder()
                .decode([ProductRow].self, from: data)
                .map(Product.init(row:))
        } catch {
            throw ServiceError.decoding(error)
        }
    }

    func searchPublishedProducts(matching query: String, limit: Int = 60) async throws -> [Product] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else {
            return []
        }

        let safeQuery = trimmedQuery
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "(", with: " ")
            .replacingOccurrences(of: ")", with: " ")
        let wildcard = "*\(safeQuery)*"
        let orFilter = "(name.ilike.\(wildcard),brand.ilike.\(wildcard),category.ilike.\(wildcard),barcode.ilike.\(wildcard))"

        let data = try await request(
            path: "rest/v1/products",
            query: [
                URLQueryItem(name: "select", value: ProductRow.selectFields),
                URLQueryItem(name: "is_published", value: "eq.true"),
                URLQueryItem(name: "or", value: orFilter),
                URLQueryItem(name: "order", value: "score.desc.nullslast"),
                URLQueryItem(name: "limit", value: String(max(1, min(limit, 100))))
            ]
        )

        do {
            return try JSONDecoder()
                .decode([ProductRow].self, from: data)
                .map(Product.init(row:))
        } catch {
            throw ServiceError.decoding(error)
        }
    }

    func fetchProduct(barcode: String) async throws -> Product? {
        let data = try await request(
            path: "rest/v1/products",
            query: [
                URLQueryItem(name: "select", value: ProductRow.selectFields),
                URLQueryItem(name: "barcode", value: "eq.\(barcode)"),
                URLQueryItem(name: "is_published", value: "eq.true"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )

        do {
            guard let row = try JSONDecoder().decode([ProductRow].self, from: data).first else {
                return nil
            }

            var product = Product(row: row)
            product = try await attachAlternatives(to: product)
            return product
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.decoding(error)
        }
    }

    private func attachAlternatives(to product: Product) async throws -> Product {
        let data = try await request(
            path: "rest/v1/product_alternatives",
            query: [
                URLQueryItem(name: "select", value: "alternative_product_id"),
                URLQueryItem(name: "product_id", value: "eq.\(product.id)"),
                URLQueryItem(name: "order", value: "rank.asc")
            ]
        )

        do {
            let rows = try JSONDecoder().decode([AlternativeRow].self, from: data)
            return product.withAlternativeIDs(rows.map(\.alternativeProductID))
        } catch {
            throw ServiceError.decoding(error)
        }
    }

    private func request(path: String, query: [URLQueryItem]) async throws -> Data {
        guard SupabaseCredentials.isConfigured else {
            throw ServiceError.notConfigured
        }

        guard let projectURL = SupabaseCredentials.projectURL else {
            throw ServiceError.invalidURL
        }

        var components = URLComponents(
            url: projectURL.appending(path: path),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = query

        guard let url = components?.url else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.setValue(SupabaseCredentials.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ServiceError.requestFailed
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ServiceError.requestFailed
        }

        return data
    }
}

nonisolated private struct ProductRow: Decodable, Sendable {
    static let selectFields = [
        "id",
        "barcode",
        "name",
        "brand",
        "category",
        "image_url",
        "ingredients",
        "nutrition",
        "score",
        "verdict",
        "summary",
        "reasons",
        "warnings",
        "positives",
        "confidence",
        "source",
        "score_version"
    ].joined(separator: ",")

    let id: String
    let barcode: String?
    let name: String
    let brand: String?
    let category: String
    let imageURL: URL?
    let ingredients: [String]
    let nutrition: Product.Nutrition
    let score: Int?
    let verdict: String
    let summary: String
    let reasons: [String]
    let warnings: [String]
    let positives: [String]
    let confidence: String
    let source: String
    let scoreVersion: String?

    enum CodingKeys: String, CodingKey {
        case id
        case barcode
        case name
        case brand
        case category
        case imageURL = "image_url"
        case ingredients
        case nutrition
        case score
        case verdict
        case summary
        case reasons
        case warnings
        case positives
        case confidence
        case source
        case scoreVersion = "score_version"
    }
}

nonisolated private struct AlternativeRow: Decodable, Sendable {
    let alternativeProductID: String

    enum CodingKeys: String, CodingKey {
        case alternativeProductID = "alternative_product_id"
    }
}

nonisolated enum ServerScoringPolicy {
    static let currentVersion = "mvp-v2"

    static func shouldUseCuratedScoring(
        version: String?,
        nutrition: Product.Nutrition,
        ingredients: [String]
    ) -> Bool {
        guard
            version?.trimmingCharacters(in: .whitespacesAndNewlines) == currentVersion,
            !nutrition.isIncomplete
        else {
            return false
        }

        return !nutrition.sugarAssessment(ingredients: ingredients).hasDataConflict
    }
}

nonisolated private extension Product {
    init(row: ProductRow) {
        let fallbackScoring = ScoringService().evaluate(
            nutrition: row.nutrition,
            ingredients: row.ingredients,
            additivesTags: [],
            category: row.category
        )
        let hasCuratedScoring = ServerScoringPolicy.shouldUseCuratedScoring(
            version: row.scoreVersion,
            nutrition: row.nutrition,
            ingredients: row.ingredients
        )
        let score = hasCuratedScoring ? row.score : fallbackScoring.score
        let summary = hasCuratedScoring ? row.summary : fallbackScoring.summary
        let reasons = hasCuratedScoring ? row.reasons : fallbackScoring.reasons
        let warnings = hasCuratedScoring ? row.warnings : fallbackScoring.warnings
        let positives = hasCuratedScoring ? row.positives : fallbackScoring.positives
        let confidence = hasCuratedScoring ? row.confidence : fallbackScoring.confidence

        self.init(
            id: row.id,
            barcode: row.barcode ?? row.id,
            name: row.name,
            brand: row.brand ?? "Unknown brand",
            category: row.category,
            imageName: "photo",
            imageURL: row.imageURL,
            ingredients: row.ingredients,
            nutrition: row.nutrition,
            nutritionSummary: fallbackScoring.nutritionSummary.isEmpty
                ? ProductNutritionSummary.make(from: row.nutrition)
                : fallbackScoring.nutritionSummary,
            score: score,
            summary: summary,
            reasons: reasons,
            warnings: warnings,
            positives: positives,
            forYouNotes: hasCuratedScoring ? [] : fallbackScoring.forYouNotes,
            alternativeIDs: [],
            confidence: confidence,
            source: Self.source(from: row.source)
        )
    }

    private static func source(from value: String) -> ProductSource {
        switch value.lowercased() {
        case "mock":
            return .mock
        case "openfoodfacts", "open_food_facts", "open-food-facts":
            return .openFoodFacts
        default:
            return .unknown
        }
    }

    func withAlternativeIDs(_ alternativeIDs: [String]) -> Product {
        Product(
            id: id,
            barcode: barcode,
            name: name,
            brand: brand,
            category: category,
            imageName: imageName,
            imageURL: imageURL,
            ingredients: ingredients,
            nutrition: nutrition,
            nutritionSummary: nutritionSummary,
            score: score,
            summary: summary,
            reasons: reasons,
            warnings: warnings,
            positives: positives,
            forYouNotes: forYouNotes,
            alternativeIDs: alternativeIDs,
            confidence: confidence,
            dietary: dietary,
            source: source
        )
    }
}

nonisolated private enum ProductNutritionSummary {
    static func make(from nutrition: Product.Nutrition) -> String {
        var values: [String] = []

        if let sugar = nutrition.addedSugars100g ?? nutrition.sugars100g {
            values.append("\(format(sugar))g sugar")
        }

        if let salt = nutrition.salt100g {
            values.append("\(format(salt))g salt")
        }

        if let protein = nutrition.proteins100g {
            values.append("\(format(protein))g protein")
        }

        return values.joined(separator: ", ")
    }

    private static func format(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return String(format: "%.1f", value)
    }
}
