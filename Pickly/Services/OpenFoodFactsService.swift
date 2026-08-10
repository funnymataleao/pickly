import Foundation

nonisolated struct OpenFoodFactsService: Sendable {
    enum ServiceError: LocalizedError {
        case invalidBarcode
        case invalidURL
        case invalidResponse
        case productNotFound
        case network(Error)
        case decoding(Error)

        var errorDescription: String? {
            switch self {
            case .invalidBarcode:
                "Enter a valid 8, 12, 13, or 14 digit product barcode."
            case .invalidURL:
                "The product request could not be created."
            case .invalidResponse:
                "Open Food Facts returned an unexpected response."
            case .productNotFound:
                "Product not found."
            case .network:
                "Couldn't load product data. Check your connection and try again."
            case .decoding:
                "Couldn't read product data."
            }
        }
    }

    private let scoringService: ScoringService
    private let session: URLSession

    init(
        scoringService: ScoringService = ScoringService(),
        session: URLSession = .shared
    ) {
        self.scoringService = scoringService
        self.session = session
    }

    func fetchProduct(barcode: String) async throws -> Product {
        guard let cleanedBarcode = BarcodeValidator.normalize(barcode) else {
            throw ServiceError.invalidBarcode
        }

        guard let url = productURL(for: cleanedBarcode) else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ServiceError.network(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            throw ServiceError.productNotFound
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ServiceError.invalidResponse
        }

        do {
            let decodedResponse = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)

            guard decodedResponse.status != "failure", let product = decodedResponse.product else {
                throw ServiceError.productNotFound
            }

            return map(
                product,
                barcode: decodedResponse.code ?? cleanedBarcode
            )
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.decoding(error)
        }
    }

    func searchProducts(matching query: String, pageSize: Int = 24) async throws -> [Product] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else {
            return []
        }

        guard let url = Self.searchURL(query: trimmedQuery, pageSize: pageSize) else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ServiceError.network(error)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw ServiceError.invalidResponse
        }

        do {
            let searchResponse = try JSONDecoder().decode(OpenFoodFactsSearchResponse.self, from: data)

            return searchResponse.products.compactMap { product in
                guard let code = clean(product.code),
                      BarcodeValidator.normalize(code) != nil else {
                    return nil
                }

                return map(product, barcode: code)
            }
        } catch {
            throw ServiceError.decoding(error)
        }
    }

    private func productURL(for barcode: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "world.openfoodfacts.org"
        components.path = "/api/v3/product/\(barcode)"
        components.queryItems = [
            URLQueryItem(name: "product_type", value: "food"),
            URLQueryItem(
                name: "fields",
                value: [
                    "code",
                    "product_name",
                    "brands",
                    "categories",
                    "categories_tags",
                    "image_front_url",
                    "image_url",
                    "ingredients",
                    "ingredients_text",
                    "nutriments",
                    "additives_tags",
                    "labels_tags",
                    "allergens_tags",
                    "traces_tags"
                ].joined(separator: ",")
            )
        ]

        return components.url
    }

    static func searchURL(query: String, pageSize: Int) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "world.openfoodfacts.org"
        components.path = "/cgi/search.pl"
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: String(max(1, min(pageSize, 50)))),
            URLQueryItem(name: "sort_by", value: "unique_scans_n"),
            URLQueryItem(name: "fields", value: [
                "code",
                "product_name",
                "brands",
                "categories",
                "categories_tags",
                "image_front_url",
                "image_url",
                "ingredients",
                "ingredients_text",
                "nutriments",
                "additives_tags",
                "labels_tags",
                "allergens_tags",
                "traces_tags"
            ].joined(separator: ","))
        ]

        return components.url
    }

    private func map(
        _ openFoodFactsProduct: OpenFoodFactsProduct,
        barcode: String
    ) -> Product {
        let nutrition = Product.Nutrition(
            sugars100g: openFoodFactsProduct.nutriments?.sugars100g,
            addedSugars100g: openFoodFactsProduct.nutriments?.addedSugars100g,
            salt100g: openFoodFactsProduct.nutriments?.salt100g,
            saturatedFat100g: openFoodFactsProduct.nutriments?.saturatedFat100g,
            proteins100g: openFoodFactsProduct.nutriments?.proteins100g,
            fiber100g: openFoodFactsProduct.nutriments?.fiber100g
        )

        let ingredients = ingredients(
            from: openFoodFactsProduct.ingredients,
            fallbackText: openFoodFactsProduct.ingredientsText
        )
        let productName = clean(openFoodFactsProduct.productName)
        let category = category(
            from: openFoodFactsProduct.categories,
            tags: openFoodFactsProduct.categoriesTags
        )
        let scoring = scoringService.evaluate(
            nutrition: nutrition,
            ingredients: ingredients,
            additivesTags: openFoodFactsProduct.additivesTags ?? [],
            hasProductName: productName != nil,
            category: category
        )

        let name = productName ?? "Unknown product"
        let brand = clean(openFoodFactsProduct.brands) ?? "Unknown brand"
        let imageURL = imageURL(from: openFoodFactsProduct)

        return Product(
            id: "off-\(barcode)",
            barcode: barcode,
            name: name,
            brand: brand,
            category: category,
            imageName: "barcode.viewfinder",
            imageURL: imageURL,
            ingredients: ingredients,
            nutrition: nutrition,
            nutritionSummary: scoring.nutritionSummary,
            score: scoring.score,
            summary: scoring.summary,
            reasons: scoring.reasons,
            warnings: scoring.warnings,
            positives: scoring.positives,
            forYouNotes: scoring.forYouNotes,
            alternativeIDs: [],
            confidence: scoring.confidence,
            dietary: dietaryAttributes(from: openFoodFactsProduct),
            source: .openFoodFacts
        )
    }

    private func ingredients(
        from structuredIngredients: [OpenFoodFactsIngredient]?,
        fallbackText: String?
    ) -> [String] {
        if let structuredIngredients, !structuredIngredients.isEmpty {
            return structuredIngredients
                .flatMap(flatten)
                .compactMap { clean($0.text) ?? clean($0.id) }
        }

        guard let fallbackText = clean(fallbackText) else {
            return []
        }

        return IngredientListParser().parse(fallbackText)
    }

    private func flatten(_ ingredient: OpenFoodFactsIngredient) -> [OpenFoodFactsIngredient] {
        [ingredient] + (ingredient.ingredients ?? []).flatMap(flatten)
    }

    private func category(from text: String?, tags: [String]?) -> String {
        if let text = clean(text), let first = text.split(separator: ",").first {
            return first.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return tags?.first
            .map { tag in
                tag
                    .split(separator: ":", maxSplits: 1)
                    .last
                    .map(String.init) ?? tag
            }
            .map { $0.replacingOccurrences(of: "-", with: " ").capitalized } ?? "Grocery"
    }

    private func dietaryAttributes(from product: OpenFoodFactsProduct) -> DietaryAttributes {
        let labels = normalizedTags(product.labelsTags)
        let allergens = normalizedTags(product.allergensTags)
        let traces = normalizedTags(product.tracesTags)
        let ingredientValues = (product.ingredients ?? []).flatMap(flatten)

        return DietaryAttributes(
            vegetarian: ingredientStatus(
                labels: labels,
                confirmedLabel: "en:vegetarian",
                negativeLabel: "en:non-vegetarian",
                values: ingredientValues.compactMap(\.vegetarian)
            ),
            vegan: ingredientStatus(
                labels: labels,
                confirmedLabel: "en:vegan",
                negativeLabel: "en:non-vegan",
                values: ingredientValues.compactMap(\.vegan)
            ),
            glutenFree: labelOrAllergenStatus(
                labels: labels,
                confirmedLabels: ["en:gluten-free", "en:no-gluten"],
                disqualifyingTags: ["en:gluten", "en:wheat"],
                allergens: allergens,
                traces: traces
            ),
            lactoseFree: labelOrAllergenStatus(
                labels: labels,
                confirmedLabels: ["en:lactose-free"],
                disqualifyingTags: ["en:milk", "en:lactose"],
                allergens: allergens,
                traces: traces
            )
        )
    }

    private func ingredientStatus(
        labels: Set<String>,
        confirmedLabel: String,
        negativeLabel: String,
        values: [String]
    ) -> DietaryStatus {
        if labels.contains(confirmedLabel) {
            return .confirmed
        }

        if labels.contains(negativeLabel) || values.contains(where: { $0.lowercased() == "no" }) {
            return .notSuitable
        }

        if !values.isEmpty, values.allSatisfy({ $0.lowercased() == "yes" }) {
            return .confirmed
        }

        return .unknown
    }

    private func labelOrAllergenStatus(
        labels: Set<String>,
        confirmedLabels: Set<String>,
        disqualifyingTags: Set<String>,
        allergens: Set<String>,
        traces: Set<String>
    ) -> DietaryStatus {
        if !allergens.isDisjoint(with: disqualifyingTags) {
            return .notSuitable
        }

        // A positive label cannot make the product confirmed when the same
        // allergen is present as a trace. Keep the result conservative.
        if !traces.isDisjoint(with: disqualifyingTags) {
            return .unknown
        }

        if !labels.isDisjoint(with: confirmedLabels) {
            return .confirmed
        }

        return .unknown
    }

    private var userAgent: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        return "Pickly/\(version) (https://github.com/funnymataleao/pickly/issues)"
    }

    private func normalizedTags(_ tags: [String]?) -> Set<String> {
        Set((tags ?? []).map { $0.lowercased() })
    }

    private func imageURL(from product: OpenFoodFactsProduct) -> URL? {
        let urlString = clean(product.imageFrontURL) ?? clean(product.imageURL)
        guard let urlString else { return nil }
        return URL(string: urlString)
    }

    private func clean(_ value: String?) -> String? {
        let cleaned = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned?.isEmpty == false ? cleaned : nil
    }
}

nonisolated private struct OpenFoodFactsResponse: Decodable, Sendable {
    let code: String?
    let status: String?
    let product: OpenFoodFactsProduct?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = container.decodeFlexibleString(forKey: .code)
        status = container.decodeFlexibleString(forKey: .status)
        product = try container.decodeIfPresent(OpenFoodFactsProduct.self, forKey: .product)
    }

    private enum CodingKeys: String, CodingKey {
        case code
        case status
        case product
    }
}

nonisolated private struct OpenFoodFactsSearchResponse: Decodable, Sendable {
    let products: [OpenFoodFactsProduct]
}

nonisolated private struct OpenFoodFactsProduct: Decodable, Sendable {
    let code: String?
    let productName: String?
    let brands: String?
    let categories: String?
    let categoriesTags: [String]?
    let imageFrontURL: String?
    let imageURL: String?
    let ingredientsText: String?
    let ingredients: [OpenFoodFactsIngredient]?
    let nutriments: OpenFoodFactsNutriments?
    let additivesTags: [String]?
    let labelsTags: [String]?
    let allergensTags: [String]?
    let tracesTags: [String]?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case categories
        case categoriesTags = "categories_tags"
        case imageFrontURL = "image_front_url"
        case imageURL = "image_url"
        case ingredientsText = "ingredients_text"
        case ingredients
        case nutriments
        case additivesTags = "additives_tags"
        case labelsTags = "labels_tags"
        case allergensTags = "allergens_tags"
        case tracesTags = "traces_tags"
    }
}

nonisolated private struct OpenFoodFactsIngredient: Decodable, Sendable {
    let id: String?
    let text: String?
    let vegan: String?
    let vegetarian: String?
    let ingredients: [OpenFoodFactsIngredient]?
}

nonisolated private struct OpenFoodFactsNutriments: Decodable, Sendable {
    let sugars100g: Double?
    let addedSugars100g: Double?
    let salt100g: Double?
    let saturatedFat100g: Double?
    let proteins100g: Double?
    let fiber100g: Double?

    enum CodingKeys: String, CodingKey {
        case sugars100g = "sugars_100g"
        case addedSugars100g = "added-sugars_100g"
        case salt100g = "salt_100g"
        case saturatedFat100g = "saturated-fat_100g"
        case proteins100g = "proteins_100g"
        case fiber100g = "fiber_100g"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sugars100g = container.decodeFlexibleDouble(forKey: .sugars100g)
        addedSugars100g = container.decodeFlexibleDouble(forKey: .addedSugars100g)
        salt100g = container.decodeFlexibleDouble(forKey: .salt100g)
        saturatedFat100g = container.decodeFlexibleDouble(forKey: .saturatedFat100g)
        proteins100g = container.decodeFlexibleDouble(forKey: .proteins100g)
        fiber100g = container.decodeFlexibleDouble(forKey: .fiber100g)
    }
}

nonisolated private extension KeyedDecodingContainer {
    func decodeFlexibleString(forKey key: Key) -> String? {
        if let value = try? decode(String.self, forKey: key) {
            return value
        }

        if let value = try? decode(Int.self, forKey: key) {
            return String(value)
        }

        if let value = try? decode(Double.self, forKey: key) {
            return String(value)
        }

        return nil
    }

    func decodeFlexibleDouble(forKey key: Key) -> Double? {
        if let value = try? decode(Double.self, forKey: key) {
            return value
        }

        if let value = try? decode(Int.self, forKey: key) {
            return Double(value)
        }

        if let value = try? decode(String.self, forKey: key) {
            return Double(value)
        }

        return nil
    }
}
