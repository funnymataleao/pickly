import Foundation

private actor OpenFoodFactsSearchGate {
    private var isHeld = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if !isHeld {
            isHeld = true
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        if waiters.isEmpty {
            isHeld = false
        } else {
            waiters.removeFirst().resume()
        }
    }
}

nonisolated struct OpenFoodFactsProductPage: Sendable {
    let products: [Product]
    let totalCount: Int
    let page: Int
    let pageSize: Int

    var hasMore: Bool {
        page * pageSize < totalCount
    }
}

nonisolated struct OpenFoodFactsService: Sendable {
    enum ServiceError: LocalizedError {
        case invalidBarcode
        case invalidURL
        case invalidResponse
        case httpStatus(Int)
        case productNotFound
        case network(Error)
        case decoding(Error)

        var errorDescription: String? {
            switch self {
            case .invalidBarcode:
                "Enter a valid 8, 12, 13, or 14 digit product barcode."
            case .invalidURL:
                "The product request could not be created."
            case .invalidResponse, .httpStatus:
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
    private let goalProxyBaseURL: URL?
    private let searchGate: OpenFoodFactsSearchGate
    private let localeContext: PicklyLocaleContext

    init(
        scoringService: ScoringService? = nil,
        session: URLSession = .shared,
        goalProxyBaseURL: URL? = nil,
        localeContext: PicklyLocaleContext = .current
    ) {
        self.scoringService = scoringService ?? ScoringService(localeContext: localeContext)
        self.session = session
        self.goalProxyBaseURL = goalProxyBaseURL
        self.searchGate = OpenFoodFactsSearchGate()
        self.localeContext = localeContext
    }

    func fetchProduct(barcode: String) async throws -> Product {
        guard let cleanedBarcode = BarcodeValidator.normalize(barcode) else {
            throw ServiceError.invalidBarcode
        }

        if let goalProxyBaseURL,
           let proxyURL = Self.productProxyURL(
               baseURL: goalProxyBaseURL,
               barcode: cleanedBarcode,
               languageCode: localeContext.openFoodFactsLanguageCode,
               countryCode: localeContext.regionCode
           ) {
            do {
                return try await fetchProduct(from: proxyURL, fallbackBarcode: cleanedBarcode)
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as ServiceError {
                switch error {
                case .httpStatus, .productNotFound, .network:
                    break
                default:
                    throw error
                }
            }
        }

        guard let url = productURL(for: cleanedBarcode, localeContext: localeContext) else {
            throw ServiceError.invalidURL
        }

        return try await fetchProduct(from: url, fallbackBarcode: cleanedBarcode)
    }

    private func fetchProduct(from url: URL, fallbackBarcode: String) async throws -> Product {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, httpResponse) = try await responseData(for: request)

        if httpResponse.statusCode == 404 {
            throw ServiceError.productNotFound
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ServiceError.httpStatus(httpResponse.statusCode)
        }

        do {
            let decodedResponse = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)

            guard decodedResponse.status != "failure", let product = decodedResponse.product else {
                throw ServiceError.productNotFound
            }

            return map(
                product,
                barcode: decodedResponse.code ?? fallbackBarcode
            )
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.decoding(error)
        }
    }

    func searchProducts(
        matching query: String,
        pageSize: Int = 24,
        page: Int = 1
    ) async throws -> [Product] {
        try await searchProductPage(
            matching: query,
            pageSize: pageSize,
            page: page
        ).products
    }

    func searchProductPage(
        matching query: String,
        pageSize: Int = 24,
        page: Int = 1,
        languageCode: String? = nil
    ) async throws -> OpenFoodFactsProductPage {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else {
            return OpenFoodFactsProductPage(products: [], totalCount: 0, page: 1, pageSize: pageSize)
        }

        guard let url = Self.searchURL(
            query: trimmedQuery,
            pageSize: pageSize,
            page: page,
            languageCode: languageCode ?? localeContext.openFoodFactsLanguageCode
        ) else {
            throw ServiceError.invalidURL
        }

        return try await searchProductPage(from: url)
    }

    /// Searches the production Open Food Facts taxonomy rather than relying on
    /// words shared by unrelated product names.
    func searchProducts(
        categoryTag: String,
        pageSize: Int = 50,
        page: Int = 1,
        countryTag: String? = nil
    ) async throws -> [Product] {
        try await searchProductPage(
            categoryTag: categoryTag,
            pageSize: pageSize,
            page: page,
            countryTag: countryTag
        ).products
    }

    func searchProductPage(
        categoryTag: String,
        pageSize: Int = 50,
        page: Int = 1,
        countryTag: String? = nil,
        languageCode: String? = nil
    ) async throws -> OpenFoodFactsProductPage {
        if let goalProxyBaseURL,
           let proxyURL = Self.categoryProxyURL(
               baseURL: goalProxyBaseURL,
               categoryTag: categoryTag,
               pageSize: pageSize,
               page: page,
               countryTag: countryTag,
               languageCode: languageCode ?? localeContext.openFoodFactsLanguageCode
           ) {
            do {
                return try await searchProductPage(from: proxyURL)
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as ServiceError {
                switch error {
                case .httpStatus(404), .network:
                    break
                default:
                    throw error
                }
            }
        }

        guard let url = Self.categorySearchURL(
            categoryTag: categoryTag,
            pageSize: pageSize,
            page: page,
            countryTag: countryTag,
            languageCode: languageCode ?? localeContext.openFoodFactsLanguageCode
        ) else {
            throw ServiceError.invalidURL
        }

        return try await searchProductPage(from: url)
    }

    /// Searches by a canonical Open Food Facts taxonomy tag whenever the goal
    /// has one. Nutrition goals use `nutrient_levels_tags`; dietary goals use
    /// explicit `labels_tags`. Pickly still applies its exact local goal rule
    /// before a mapped product reaches that goal's feed.
    func searchProducts(
        for goal: GroceryGoal,
        pageSize: Int = 24,
        page: Int = 1
    ) async throws -> [Product] {
        try await searchProductPage(for: goal, pageSize: pageSize, page: page).products
    }

    func searchProductPage(
        for goal: GroceryGoal,
        pageSize: Int = 24,
        page: Int = 1,
        languageCode: String? = nil
    ) async throws -> OpenFoodFactsProductPage {
        if let goalProxyBaseURL,
           let proxyURL = Self.goalProxyURL(
               baseURL: goalProxyBaseURL,
               goal: goal,
               pageSize: pageSize,
               page: page,
               languageCode: languageCode ?? localeContext.openFoodFactsLanguageCode
           ) {
            do {
                return try await searchProductPage(from: proxyURL)
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as ServiceError {
                // A new Worker route can roll out independently from the app.
                // Fall back only when the route is absent or the Worker itself
                // cannot be reached. A proxy 429/5xx already represents an OFF
                // attempt and must not be amplified by another direct request.
                switch error {
                case .httpStatus(404), .network:
                    break
                default:
                    throw error
                }
            }
        }

        if let nutrientLevelTag = goal.catalogNutrientLevelTag {
            guard let url = Self.nutrientLevelSearchURL(
                tag: nutrientLevelTag,
                pageSize: pageSize,
                page: page,
                languageCode: languageCode ?? localeContext.openFoodFactsLanguageCode
            ) else {
                throw ServiceError.invalidURL
            }
            return try await searchProductPage(from: url)
        }

        if let labelTag = goal.catalogLabelTag {
            guard let url = Self.labelSearchURL(
                label: labelTag,
                pageSize: pageSize,
                page: page,
                languageCode: languageCode ?? localeContext.openFoodFactsLanguageCode
            ) else {
                throw ServiceError.invalidURL
            }
            return try await searchProductPage(from: url)
        }

        return try await searchProductPage(
            matching: goal.catalogSearchQuery,
            pageSize: pageSize,
            page: page,
            languageCode: languageCode ?? localeContext.openFoodFactsLanguageCode
        )
    }

    private func searchProducts(from url: URL) async throws -> [Product] {
        try await searchProductPage(from: url).products
    }

    private func searchProductPage(from url: URL) async throws -> OpenFoodFactsProductPage {
        await searchGate.acquire()
        do {
            let page = try await performSearchProductPage(from: url)
            await searchGate.release()
            return page
        } catch {
            await searchGate.release()
            throw error
        }
    }

    private func performSearchProductPage(from url: URL) async throws -> OpenFoodFactsProductPage {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, httpResponse) = try await responseData(for: request)
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ServiceError.httpStatus(httpResponse.statusCode)
        }

        do {
            let searchResponse = try JSONDecoder().decode(OpenFoodFactsSearchResponse.self, from: data)

            let products: [Product] = searchResponse.products.compactMap { product -> Product? in
                guard let code = clean(product.code),
                      BarcodeValidator.normalize(code) != nil else {
                    return nil
                }

                return map(product, barcode: code)
            }
            let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            let requestedPage = queryItems?
                .first(where: { $0.name == "page" })?
                .value
                .flatMap(Int.init)
            let requestedPageSize = queryItems?
                .first(where: { $0.name == "page_size" })?
                .value
                .flatMap(Int.init)
            let resolvedPage = max(1, searchResponse.page ?? requestedPage ?? 1)
            let resolvedPageSize = max(1, searchResponse.pageSize ?? requestedPageSize ?? products.count)
            return OpenFoodFactsProductPage(
                products: products,
                totalCount: max(products.count, searchResponse.count ?? products.count),
                page: resolvedPage,
                pageSize: resolvedPageSize
            )
        } catch {
            throw ServiceError.decoding(error)
        }
    }

    private func responseData(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        for attempt in 0..<2 {
            do {
                try Task.checkCancellation()
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ServiceError.invalidResponse
                }

                return (data, httpResponse)
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as ServiceError {
                throw error
            } catch {
                if attempt == 0 {
                    try await Task.sleep(for: .milliseconds(250))
                    continue
                }
                throw ServiceError.network(error)
            }
        }

        throw ServiceError.invalidResponse
    }

    /// Keep the upstream payload explicit and bounded while including every
    /// supported display language plus the English fallback.
    private static let openFoodFactsFields: String = {
        let baseFields = [
            "code", "product_name", "generic_name", "lang", "languages_tags",
            "brands", "categories", "categories_tags", "countries_tags",
            "quantity", "serving_size", "nutrition_data_per",
            "image_front_url", "image_url",
            "selected_images", "ingredients", "ingredients_text", "ingredients_lc",
            "ingredients_n", "ingredients_tags", "nutriments", "nutrition", "additives_tags",
            "labels_tags", "allergens_tags", "traces_tags", "completeness", "last_modified_t",
            "data_quality_warnings_tags"
        ]
        let localizedCodes = ["en", "pt", "es", "fr", "de", "it", "da", "pl", "cs"]
        let localizedFields = localizedCodes.flatMap { code in
            ["product_name_\(code)", "generic_name_\(code)", "ingredients_text_\(code)"]
        }
        return Array(NSOrderedSet(array: baseFields + localizedFields))
            .compactMap { $0 as? String }
            .joined(separator: ",")
    }()

    private func productURL(
        for barcode: String,
        localeContext: PicklyLocaleContext
    ) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "world.openfoodfacts.org"
        components.path = "/api/v3.6/product/\(barcode).json"
        components.queryItems = [
            URLQueryItem(name: "product_type", value: "food"),
            URLQueryItem(name: "lc", value: localeContext.openFoodFactsLanguageCode),
            URLQueryItem(name: "tags_lc", value: localeContext.openFoodFactsLanguageCode),
            URLQueryItem(name: "cc", value: localeContext.regionCode.lowercased()),
            URLQueryItem(
                name: "fields",
                value: Self.openFoodFactsFields
            )
        ]

        return components.url
    }

    static func searchURL(
        query: String,
        pageSize: Int,
        page: Int = 1,
        languageCode: String? = nil
    ) -> URL? {
        searchURL(
            query: query,
            pageSize: pageSize,
            page: page,
            host: "world.openfoodfacts.org",
            languageCode: languageCode ?? "en"
        )
    }

    private static func searchURL(
        query: String,
        pageSize: Int,
        page: Int,
        host: String,
        languageCode: String
    ) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/cgi/search.pl"
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: String(max(1, min(pageSize, 50)))),
            URLQueryItem(name: "page", value: String(max(1, page))),
            URLQueryItem(name: "sort_by", value: "unique_scans_n"),
            URLQueryItem(name: "lc", value: languageCode),
            URLQueryItem(name: "fields", value: Self.openFoodFactsFields)
        ]

        return components.url
    }

    static func categorySearchURL(
        categoryTag: String,
        pageSize: Int,
        page: Int = 1,
        countryTag: String? = nil,
        languageCode: String? = nil
    ) -> URL? {
        categorySearchURL(
            categoryTag: categoryTag,
            pageSize: pageSize,
            page: page,
            countryTag: countryTag,
            host: "world.openfoodfacts.org",
            languageCode: languageCode ?? productLanguageCode(for: countryTag)
        )
    }

    private static func categorySearchURL(
        categoryTag: String,
        pageSize: Int,
        page: Int,
        countryTag: String?,
        host: String,
        languageCode: String
    ) -> URL? {
        let normalizedTag = categoryTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTag.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/api/v2/search"
        var queryItems = [
            URLQueryItem(name: "product_type", value: "food"),
            URLQueryItem(name: "categories_tags", value: normalizedTag),
            URLQueryItem(name: "lc", value: languageCode),
            URLQueryItem(name: "page_size", value: String(max(1, min(pageSize, 50)))),
            URLQueryItem(name: "page", value: String(max(1, page))),
            URLQueryItem(name: "sort_by", value: "unique_scans_n"),
            URLQueryItem(name: "fields", value: Self.openFoodFactsFields)
        ]
        if let countryTag = countryTag?.trimmingCharacters(in: .whitespacesAndNewlines),
           !countryTag.isEmpty {
            queryItems.insert(URLQueryItem(name: "countries_tags_en", value: countryTag.replacingOccurrences(of: "en:", with: "")), at: 2)
        }
        components.queryItems = queryItems

        return components.url
    }

    static func categoryProxyURL(
        baseURL: URL,
        categoryTag: String,
        pageSize: Int,
        page: Int = 1,
        countryTag: String? = nil,
        languageCode: String? = nil
    ) -> URL? {
        let normalizedTag = categoryTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTag.isEmpty else { return nil }

        var components = URLComponents(
            url: baseURL.appending(path: "v1/categories/\(normalizedTag)"),
            resolvingAgainstBaseURL: false
        )
        var queryItems = [
            URLQueryItem(name: "page_size", value: String(max(1, min(pageSize, 50)))),
            URLQueryItem(name: "page", value: String(max(1, page))),
            URLQueryItem(name: "lang", value: languageCode ?? productLanguageCode(for: countryTag))
        ]
        if let countryTag = countryTag?.trimmingCharacters(in: .whitespacesAndNewlines),
           !countryTag.isEmpty {
            queryItems.append(URLQueryItem(name: "country", value: countryTag))
        }
        components?.queryItems = queryItems
        return components?.url
    }

    static func productLanguageCode(for countryTag: String?) -> String {
        switch countryTag?.lowercased() {
        case "en:portugal": "pt"
        case "en:spain": "es"
        case "en:france": "fr"
        case "en:germany", "en:austria": "de"
        case "en:italy": "it"
        default: "en"
        }
    }

    static func productProxyURL(
        baseURL: URL,
        barcode: String,
        languageCode: String = "en",
        countryCode: String? = nil
    ) -> URL? {
        guard BarcodeValidator.normalize(barcode) != nil else { return nil }
        var components = URLComponents(
            url: baseURL.appending(path: "v1/off/products/\(barcode)"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "lang", value: languageCode),
            URLQueryItem(name: "country", value: countryCode?.lowercased())
        ].filter { $0.value != nil }
        return components?.url
    }

    static func labelSearchURL(
        label: String,
        pageSize: Int,
        page: Int = 1,
        languageCode: String = "en"
    ) -> URL? {
        taxonomySearchURL(
            queryItemName: "labels_tags",
            tag: label,
            pageSize: pageSize,
            page: page,
            languageCode: languageCode
        )
    }

    static func nutrientLevelSearchURL(
        tag: String,
        pageSize: Int,
        page: Int = 1,
        languageCode: String = "en"
    ) -> URL? {
        taxonomySearchURL(
            queryItemName: "nutrient_levels_tags",
            tag: tag,
            pageSize: pageSize,
            page: page,
            languageCode: languageCode
        )
    }

    static func goalProxyURL(
        baseURL: URL,
        goal: GroceryGoal,
        pageSize: Int,
        page: Int = 1,
        languageCode: String = "en"
    ) -> URL? {
        guard goal.catalogNutrientLevelTag != nil || goal.catalogLabelTag != nil else {
            return nil
        }

        var components = URLComponents(
            url: baseURL.appending(path: "v1/goals/\(goal.rawValue)"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "page_size", value: String(max(1, min(pageSize, 50)))),
            URLQueryItem(name: "page", value: String(max(1, page))),
            URLQueryItem(name: "lang", value: languageCode)
        ]
        return components?.url
    }

    private static func taxonomySearchURL(
        queryItemName: String,
        tag: String,
        pageSize: Int,
        page: Int,
        languageCode: String
    ) -> URL? {
        let normalizedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTag.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "world.openfoodfacts.org"
        components.path = "/api/v2/search"
        components.queryItems = [
            URLQueryItem(name: "product_type", value: "food"),
            URLQueryItem(name: queryItemName, value: normalizedTag),
            URLQueryItem(name: "page_size", value: String(max(1, min(pageSize, 50)))),
            URLQueryItem(name: "page", value: String(max(1, page))),
            URLQueryItem(name: "sort_by", value: "unique_scans_n"),
            URLQueryItem(name: "lc", value: languageCode),
            URLQueryItem(name: "fields", value: Self.openFoodFactsFields)
        ]

        return components.url
    }

    private func map(
        _ openFoodFactsProduct: OpenFoodFactsProduct,
        barcode: String
    ) -> Product {
        let structuredNutrients = openFoodFactsProduct.structuredNutrition?
            .aggregatedSet?
            .nutrients
        let nutrition = Product.Nutrition(
            energyKcal100g: openFoodFactsProduct.nutriments?.energyKcal100g
                ?? structuredNutrients?["energy-kcal"]?.verifiedValue,
            energyKJ100g: openFoodFactsProduct.nutriments?.energyKJ100g
                ?? structuredNutrients?["energy-kj"]?.verifiedValue
                ?? structuredNutrients?["energy"]?.verifiedValue,
            fat100g: openFoodFactsProduct.nutriments?.fat100g
                ?? structuredNutrients?["fat"]?.verifiedGramsValue,
            carbohydrates100g: openFoodFactsProduct.nutriments?.carbohydrates100g
                ?? structuredNutrients?["carbohydrates"]?.verifiedGramsValue,
            sugars100g: openFoodFactsProduct.nutriments?.sugars100g
                ?? structuredNutrients?["sugars"]?.verifiedGramsValue,
            addedSugars100g: openFoodFactsProduct.nutriments?.addedSugars100g
                ?? structuredNutrients?["added-sugars"]?.verifiedGramsValue,
            salt100g: openFoodFactsProduct.nutriments?.salt100g
                ?? structuredNutrients?["salt"]?.verifiedGramsValue,
            sodium100g: openFoodFactsProduct.nutriments?.sodium100g
                ?? structuredNutrients?["sodium"]?.verifiedGramsValue,
            saturatedFat100g: openFoodFactsProduct.nutriments?.saturatedFat100g
                ?? structuredNutrients?["saturated-fat"]?.verifiedGramsValue,
            proteins100g: openFoodFactsProduct.nutriments?.proteins100g
                ?? structuredNutrients?["proteins"]?.verifiedGramsValue,
            fiber100g: openFoodFactsProduct.nutriments?.fiber100g
                ?? structuredNutrients?["fiber"]?.verifiedGramsValue
        )

        let requestedLanguage = localeContext.openFoodFactsLanguageCode
        // Never trust a `product_name_en` field solely because its suffix says
        // English: OFF records occasionally contain a French/German label in
        // that field. English goes through the verified resolver below; the
        // other supported locales may use their explicit localized field.
        let localizedName = requestedLanguage == "en"
            ? nil
            : openFoodFactsProduct.localizedProductNames[requestedLanguage]
        let localizedGenericName = requestedLanguage == "en"
            ? nil
            : openFoodFactsProduct.localizedGenericNames[requestedLanguage]
        let localizedIngredientsText = openFoodFactsProduct.localizedIngredientsTexts[requestedLanguage]
        let ingredients = ingredients(
            from: openFoodFactsProduct.ingredients,
            fallbackText: localizedIngredientsText ?? openFoodFactsProduct.ingredientsText
        )
        let category = category(
            from: openFoodFactsProduct.categories,
            tags: openFoodFactsProduct.categoriesTags
        )
        let brand = clean(openFoodFactsProduct.brands) ?? "Unknown brand"
        let rawEnglishName = clean(openFoodFactsProduct.language)?.lowercased().hasPrefix("en") == true
            ? openFoodFactsProduct.productName
            : nil
        let nameCandidates = [
            openFoodFactsProduct.productNameEnglish,
            openFoodFactsProduct.genericNameEnglish,
            rawEnglishName
        ]
        let verifiedProductName = EnglishProductNameResolver.verifiedName(
            candidates: nameCandidates,
            brand: clean(openFoodFactsProduct.brands),
            categoryTags: openFoodFactsProduct.categoriesTags ?? []
        )
        let sourceLanguage = clean(openFoodFactsProduct.language)?.lowercased()
        let sourceName = sourceLanguage?.hasPrefix(requestedLanguage) == true
            ? clean(openFoodFactsProduct.productName)
            : nil
        let trustedSourceName = requestedLanguage == "en"
            ? EnglishProductNameResolver.verifiedName(
                candidates: [sourceName],
                brand: clean(openFoodFactsProduct.brands),
                categoryTags: openFoodFactsProduct.categoriesTags ?? []
            )
            : sourceName
        let productName = localizedName
            ?? localizedGenericName
            ?? trustedSourceName
            ?? verifiedProductName
            ?? EnglishProductNameResolver.resolvedName(
                candidates: nameCandidates,
                brand: clean(openFoodFactsProduct.brands),
                category: category,
                categoryTags: openFoodFactsProduct.categoriesTags ?? []
            )
        let scoring = scoringService.evaluate(
            nutrition: nutrition,
            ingredients: ingredients,
            additivesTags: openFoodFactsProduct.additivesTags ?? [],
            hasProductName: productName != "Unknown product",
            category: category
        )
        let imageURL = imageURL(from: openFoodFactsProduct)
        let facts = Product.Facts(
            quantity: clean(openFoodFactsProduct.quantity),
            servingSize: clean(openFoodFactsProduct.servingSize),
            nutritionBasis: nutritionBasis(from: openFoodFactsProduct),
            allergens: normalizedFactTags(openFoodFactsProduct.allergensTags),
            traces: normalizedFactTags(openFoodFactsProduct.tracesTags),
            additives: normalizedFactTags(openFoodFactsProduct.additivesTags),
            labels: normalizedFactTags(openFoodFactsProduct.labelsTags),
            countries: normalizedFactTags(openFoodFactsProduct.countriesTags),
            completeness: openFoodFactsProduct.completeness,
            lastUpdatedAt: openFoodFactsProduct.lastModifiedTimestamp.map(Date.init(timeIntervalSince1970:)),
            source: .openFoodFacts
        )

        return Product(
            id: "off-\(barcode)",
            barcode: barcode,
            name: productName,
            brand: brand,
            category: category,
            categoryTags: openFoodFactsProduct.categoriesTags ?? [],
            imageName: "barcode.viewfinder",
            imageURL: imageURL,
            ingredients: ingredients,
            declaredIngredientCount: openFoodFactsProduct.ingredientsCount,
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
            source: .openFoodFacts,
            facts: facts
        )
    }

    private func nutritionBasis(from product: OpenFoodFactsProduct) -> Product.NutritionBasis {
        let rawValue = clean(product.structuredNutrition?.aggregatedSet?.per)
            ?? clean(product.nutritionDataPer)
        switch rawValue?.lowercased().replacingOccurrences(of: " ", with: "") {
        case "100ml", "per100ml":
            return .per100ml
        case "serving", "perserving":
            return .perServing
        case "100g", "per100g":
            return .per100g
        default:
            return product.nutriments == nil && product.structuredNutrition == nil
                ? .unknown
                : .per100g
        }
    }

    private func normalizedFactTags(_ values: [String]?) -> [String] {
        var seen = Set<String>()
        return (values ?? [])
            .compactMap(clean)
            .filter { seen.insert($0.lowercased()).inserted }
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
        if let tags,
           let specificTag = ProductText.orderedStrongCategoryTags(in: tags).last {
            return normalizedCategoryName(specificTag)
        }

        if let text = clean(text), let last = text.split(separator: ",").last {
            return normalizedCategoryName(String(last))
        }

        return "Grocery"
    }

    private func normalizedCategoryName(_ value: String) -> String {
        let category = value
            .split(separator: ":", maxSplits: 1)
            .last
            .map(String.init) ?? value
        let cleaned = category
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Grocery" : cleaned.capitalized
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
                confirmedLabels: ["en:lactose-free", "en:no-lactose", "en:without-lactose"],
                // Lactose-free dairy can still contain milk proteins. The
                // milk allergen is therefore not a reason to reject a
                // product that carries an explicit no-lactose label.
                disqualifyingTags: ["en:lactose"],
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
        if labels.contains(negativeLabel) || values.contains(where: { $0.lowercased() == "no" }) {
            return .notSuitable
        }

        if labels.contains(confirmedLabel) {
            return .confirmed
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
    let count: Int?
    let page: Int?
    let pageSize: Int?

    private enum CodingKeys: String, CodingKey {
        case products
        case count
        case page
        case pageSize = "page_size"
    }
}

nonisolated private struct OpenFoodFactsProduct: Decodable, Sendable {
    let code: String?
    let productName: String?
    let productNameEnglish: String?
    let genericNameEnglish: String?
    let localizedProductNames: [String: String]
    let localizedGenericNames: [String: String]
    let localizedIngredientsTexts: [String: String]
    let language: String?
    let brands: String?
    let categories: String?
    let categoriesTags: [String]?
    let countriesTags: [String]?
    let quantity: String?
    let servingSize: String?
    let nutritionDataPer: String?
    let imageFrontURL: String?
    let imageURL: String?
    let ingredientsText: String?
    let ingredientsCount: Int?
    let ingredients: [OpenFoodFactsIngredient]?
    let nutriments: OpenFoodFactsNutriments?
    let structuredNutrition: OpenFoodFactsStructuredNutrition?
    let additivesTags: [String]?
    let labelsTags: [String]?
    let allergensTags: [String]?
    let tracesTags: [String]?
    let completeness: Double?
    let lastModifiedTimestamp: Double?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case productNameEnglish = "product_name_en"
        case genericNameEnglish = "generic_name_en"
        case language = "lang"
        case brands
        case categories
        case categoriesTags = "categories_tags"
        case countriesTags = "countries_tags"
        case quantity
        case servingSize = "serving_size"
        case nutritionDataPer = "nutrition_data_per"
        case imageFrontURL = "image_front_url"
        case imageURL = "image_url"
        case ingredientsText = "ingredients_text"
        case ingredientsCount = "ingredients_n"
        case ingredients
        case nutriments
        case structuredNutrition = "nutrition"
        case additivesTags = "additives_tags"
        case labelsTags = "labels_tags"
        case allergensTags = "allergens_tags"
        case tracesTags = "traces_tags"
        case completeness
        case lastModifiedTimestamp = "last_modified_t"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dynamicContainer = try decoder.container(keyedBy: DynamicCodingKey.self)
        code = container.decodeFlexibleString(forKey: .code)
        productName = container.decodeFlexibleString(forKey: .productName)
        productNameEnglish = container.decodeEnglishString(forKey: .productNameEnglish)
            ?? container.decodeLocalizedEnglishString(forKey: .productName)
        genericNameEnglish = container.decodeEnglishString(forKey: .genericNameEnglish)
        localizedProductNames = Self.localizedValues(
            from: dynamicContainer,
            baseKey: "product_name"
        )
        localizedGenericNames = Self.localizedValues(
            from: dynamicContainer,
            baseKey: "generic_name"
        )
        localizedIngredientsTexts = Self.localizedValues(
            from: dynamicContainer,
            baseKey: "ingredients_text"
        )
        language = container.decodeFlexibleString(forKey: .language)
        brands = container.decodeFlexibleString(forKey: .brands)
        categories = container.decodeFlexibleString(forKey: .categories)
        categoriesTags = try container.decodeIfPresent([String].self, forKey: .categoriesTags)
        countriesTags = try container.decodeIfPresent([String].self, forKey: .countriesTags)
        quantity = container.decodeFlexibleString(forKey: .quantity)
        servingSize = container.decodeFlexibleString(forKey: .servingSize)
        nutritionDataPer = container.decodeFlexibleString(forKey: .nutritionDataPer)
        imageFrontURL = container.decodeFlexibleString(forKey: .imageFrontURL)
        imageURL = container.decodeFlexibleString(forKey: .imageURL)
        ingredientsText = container.decodeFlexibleString(forKey: .ingredientsText)
        ingredientsCount = container.decodeFlexibleInt(forKey: .ingredientsCount)
        ingredients = try container.decodeIfPresent([OpenFoodFactsIngredient].self, forKey: .ingredients)
        nutriments = try container.decodeIfPresent(OpenFoodFactsNutriments.self, forKey: .nutriments)
        structuredNutrition = try container.decodeIfPresent(
            OpenFoodFactsStructuredNutrition.self,
            forKey: .structuredNutrition
        )
        additivesTags = try container.decodeIfPresent([String].self, forKey: .additivesTags)
        labelsTags = try container.decodeIfPresent([String].self, forKey: .labelsTags)
        allergensTags = try container.decodeIfPresent([String].self, forKey: .allergensTags)
        tracesTags = try container.decodeIfPresent([String].self, forKey: .tracesTags)
        completeness = container.decodeFlexibleDouble(forKey: .completeness)
        lastModifiedTimestamp = container.decodeFlexibleDouble(forKey: .lastModifiedTimestamp)
    }

    private static let languageCodes = ["en", "pt", "es", "fr", "de", "it", "da", "pl", "cs"]

    private static func localizedValues(
        from container: KeyedDecodingContainer<DynamicCodingKey>,
        baseKey: String
    ) -> [String: String] {
        var values: [String: String] = [:]
        for languageCode in languageCodes {
            guard let key = DynamicCodingKey(stringValue: "\(baseKey)_\(languageCode)") else { continue }
            if let value = container.decodeFlexibleString(forKey: key) {
                values[languageCode] = value
            }
        }

        guard let key = DynamicCodingKey(stringValue: baseKey) else { return values }
        if let nested = container.decodeStringMap(forKey: key) {
            for (languageCode, value) in nested where values[languageCode] == nil {
                values[languageCode] = value
            }
        }
        return values
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
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
    let energyKcal100g: Double?
    let energyKJ100g: Double?
    let fat100g: Double?
    let carbohydrates100g: Double?
    let sugars100g: Double?
    let addedSugars100g: Double?
    let salt100g: Double?
    let sodium100g: Double?
    let saturatedFat100g: Double?
    let proteins100g: Double?
    let fiber100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case energyKJ100g = "energy-kj_100g"
        case fat100g = "fat_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case sugars100g = "sugars_100g"
        case addedSugars100g = "added-sugars_100g"
        case salt100g = "salt_100g"
        case sodium100g = "sodium_100g"
        case saturatedFat100g = "saturated-fat_100g"
        case proteins100g = "proteins_100g"
        case fiber100g = "fiber_100g"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        energyKcal100g = container.decodeFlexibleDouble(forKey: .energyKcal100g)
        energyKJ100g = container.decodeFlexibleDouble(forKey: .energyKJ100g)
        fat100g = container.decodeFlexibleDouble(forKey: .fat100g)
        carbohydrates100g = container.decodeFlexibleDouble(forKey: .carbohydrates100g)
        sugars100g = container.decodeFlexibleDouble(forKey: .sugars100g)
        addedSugars100g = container.decodeFlexibleDouble(forKey: .addedSugars100g)
        salt100g = container.decodeFlexibleDouble(forKey: .salt100g)
        sodium100g = container.decodeFlexibleDouble(forKey: .sodium100g)
        saturatedFat100g = container.decodeFlexibleDouble(forKey: .saturatedFat100g)
        proteins100g = container.decodeFlexibleDouble(forKey: .proteins100g)
        fiber100g = container.decodeFlexibleDouble(forKey: .fiber100g)
    }
}

nonisolated private struct OpenFoodFactsStructuredNutrition: Decodable, Sendable {
    let aggregatedSet: OpenFoodFactsAggregatedNutrition?

    enum CodingKeys: String, CodingKey {
        case aggregatedSet = "aggregated_set"
    }
}

nonisolated private struct OpenFoodFactsAggregatedNutrition: Decodable, Sendable {
    let nutrients: [String: OpenFoodFactsNutrient]?
    let per: String?
}

nonisolated private struct OpenFoodFactsNutrient: Decodable, Sendable {
    let value: Double?
    let unit: String?
    let source: String?
    let modifier: String?

    enum CodingKeys: String, CodingKey {
        case value
        case unit
        case source
        case modifier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = container.decodeFlexibleDouble(forKey: .value)
        unit = container.decodeFlexibleString(forKey: .unit)
        source = container.decodeFlexibleString(forKey: .source)
        modifier = container.decodeFlexibleString(forKey: .modifier)
    }

    var verifiedValue: Double? {
        guard source?.lowercased() != "estimate", modifier != "~" else {
            return nil
        }
        return value
    }

    var verifiedGramsValue: Double? {
        guard let verifiedValue else { return nil }
        switch unit?.lowercased() {
        case "mg":
            return verifiedValue / 1_000
        case "µg", "ug":
            return verifiedValue / 1_000_000
        default:
            return verifiedValue
        }
    }
}

nonisolated private extension KeyedDecodingContainer {
    func decodeStringMap(forKey key: Key) -> [String: String]? {
        guard let localized = try? decode([String: String].self, forKey: key) else {
            return nil
        }
        return localized.reduce(into: [String: String]()) { result, entry in
            let value = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                result[entry.key.lowercased()] = value
            }
        }
    }

    func decodeLocalizedEnglishString(forKey key: Key) -> String? {
        guard let localized = try? decode([String: String].self, forKey: key),
              let english = localized["en"],
              !english.isEmpty else {
            return nil
        }
        return english
    }

    func decodeEnglishString(forKey key: Key) -> String? {
        if let value = try? decode(String.self, forKey: key), !value.isEmpty {
            return value
        }

        return decodeLocalizedEnglishString(forKey: key)
    }

    func decodeFlexibleString(forKey key: Key) -> String? {
        if let value = try? decode(String.self, forKey: key) {
            return value
        }

        if let localized = try? decode([String: String].self, forKey: key) {
            if let english = localized["en"], !english.isEmpty {
                return english
            }
            for identifier in Locale.preferredLanguages {
                let code = Locale(identifier: identifier).language.languageCode?.identifier.lowercased()
                if let code, let value = localized[code], !value.isEmpty {
                    return value
                }
            }
            if let main = localized["main"], !main.isEmpty {
                return main
            }
            return localized.keys.sorted().compactMap { localized[$0] }.first { !$0.isEmpty }
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

    func decodeFlexibleInt(forKey key: Key) -> Int? {
        if let value = try? decode(Int.self, forKey: key) {
            return value
        }

        if let value = try? decode(Double.self, forKey: key), value.isFinite {
            return Int(value)
        }

        if let value = try? decode(String.self, forKey: key) {
            return Int(value)
        }

        return nil
    }
}
