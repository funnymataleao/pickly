import Combine
import Foundation

@MainActor
final class ProductCatalogStore: ObservableObject, ProductService, ProductLookupService {
    enum CatalogError: LocalizedError {
        case notFound

        var errorDescription: String? {
            switch self {
            case .notFound:
                "Product not found."
            }
        }
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingGoalRecommendations = false
    @Published private(set) var goalRecommendationsErrorMessage: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasLoaded = false

    private let supabaseService: SupabaseProductService
    private let openFoodFactsService: OpenFoodFactsService
    private let fallbackProducts: [Product]
    private let remoteEnabled: Bool
    private let prototypeFallbackEnabled: Bool
    private var loadedQueries = Set<String>()
    private var loadedRelatedCategories = Set<String>()
    private var relatedProductIDsByCategory: [String: [String]] = [:]
    private var loadedGoalQueries = Set<String>()

    init(
        supabaseService: SupabaseProductService = SupabaseProductService(),
        openFoodFactsService: OpenFoodFactsService = OpenFoodFactsService(),
        fallbackProducts: [Product]? = nil,
        remoteEnabled: Bool? = nil,
        prototypeFallbackEnabled: Bool? = nil
    ) {
        self.supabaseService = supabaseService
        self.openFoodFactsService = openFoodFactsService
        let resolvedFallbackProducts = fallbackProducts ?? MockProductService().products
        let resolvedRemoteEnabled = remoteEnabled ?? SupabaseCredentials.isConfigured
        #if DEBUG
        let resolvedPrototypeFallbackEnabled = prototypeFallbackEnabled ?? true
        #else
        let resolvedPrototypeFallbackEnabled = prototypeFallbackEnabled ?? false
        #endif
        self.fallbackProducts = resolvedFallbackProducts
        self.remoteEnabled = resolvedRemoteEnabled
        self.prototypeFallbackEnabled = resolvedPrototypeFallbackEnabled
        // Do not mix prototype fixtures with the published catalog. The fixture
        // barcodes are intentionally different and their image URLs are nil, so
        // rendering both sets creates duplicate cards with placeholder icons.
        self.products = !resolvedRemoteEnabled && resolvedPrototypeFallbackEnabled
            ? resolvedFallbackProducts
            : []
        self.hasLoaded = !resolvedRemoteEnabled && resolvedPrototypeFallbackEnabled
    }

    static var preview: ProductCatalogStore {
        ProductCatalogStore(
            fallbackProducts: MockProductService().products,
            remoteEnabled: false,
            prototypeFallbackEnabled: true
        )
    }

    func loadInitial() async {
        guard !hasLoaded, !isLoading else { return }

        guard remoteEnabled else {
            products = prototypeFallbackEnabled ? fallbackProducts : []
            if !prototypeFallbackEnabled {
                errorMessage = "Product catalog is not configured for this build yet."
            }
            hasLoaded = true
            return
        }

        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            let remoteProducts = try await supabaseService.fetchPublishedProducts()
            if remoteProducts.isEmpty {
                products = []
                errorMessage = "No catalog products are available right now."
            } else {
                merge(remoteProducts)
            }
        } catch {
            products = []
            errorMessage = "Couldn't load product data. Check your connection and try again."
        }
    }

    func search(query: String) async {
        let normalizedQuery = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard normalizedQuery.count >= 2 else {
            return
        }

        guard remoteEnabled else {
            if !prototypeFallbackEnabled {
                errorMessage = "Product catalog is not configured for this build yet."
            }
            return
        }

        guard !loadedQueries.contains(normalizedQuery) else {
            return
        }

        if !searchProducts(matching: normalizedQuery).isEmpty {
            loadedQueries.insert(normalizedQuery)
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let catalogProducts = try await supabaseService.searchPublishedProducts(matching: query)
            merge(catalogProducts)

            if catalogProducts.isEmpty {
                let fetchedProducts = try await openFoodFactsService.searchProducts(matching: query)
                merge(fetchedProducts)
            }

            loadedQueries.insert(normalizedQuery)
        } catch let error as OpenFoodFactsService.ServiceError {
            errorMessage = error.errorDescription
        } catch {
            do {
                let fetchedProducts = try await openFoodFactsService.searchProducts(matching: query)
                merge(fetchedProducts)
                loadedQueries.insert(normalizedQuery)
            } catch let error as OpenFoodFactsService.ServiceError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = "Couldn't load product data. Check your connection and try again."
            }
        }
    }

    func fetchProduct(barcode: String) async throws -> Product {
        if let localProduct = products.first(where: { $0.barcode == barcode }) {
            return localProduct
        }

        guard remoteEnabled else {
            throw CatalogError.notFound
        }

        do {
            if let remoteProduct = try await supabaseService.fetchProduct(barcode: barcode) {
                merge([remoteProduct])
                return remoteProduct
            }
        } catch {
            // A cache miss or a temporary Supabase failure falls back to Open Food Facts.
        }

        let fetchedProduct = try await openFoodFactsService.fetchProduct(barcode: barcode)
        merge([fetchedProduct])
        return fetchedProduct
    }

    func alternatives(for product: Product) -> [Product] {
        let explicitAlternatives = product.alternativeIDs.compactMap(product(id:))
        if !explicitAlternatives.isEmpty {
            return explicitAlternatives
        }

        guard let score = product.score else {
            return []
        }

        return products
            .filter { candidate in
                candidate.id != product.id
                    && candidate.category.caseInsensitiveCompare(product.category) == .orderedSame
                    && !candidate.isLimitedData
                    && (candidate.score ?? 0) > score
            }
            .sorted { ($0.score ?? 0) > ($1.score ?? 0) }
            .prefix(8)
            .map { $0 }
    }

    func relatedProducts(for product: Product, limit: Int) async -> [Product] {
        let categoryKey = product.category
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let fetchedMatches = relatedProductIDsByCategory[categoryKey, default: []]
            .compactMap { self.product(id: $0) }
        let localProducts = RelatedProductRanker.products(
            for: product,
            explicitAlternatives: alternatives(for: product) + fetchedMatches,
            catalog: products,
            limit: limit
        )
        guard limit > localProducts.count, remoteEnabled else {
            return localProducts
        }

        guard !categoryKey.isEmpty else { return localProducts }

        if !loadedRelatedCategories.contains(categoryKey) {
            do {
                let fetchedProducts = try await openFoodFactsService.searchProducts(
                    matching: product.category,
                    pageSize: min(50, max(limit + 10, 30))
                )
                let usableFetchedProducts = fetchedProducts.filter {
                    $0.name != "Unknown product" && $0.imageURL != nil
                }
                merge(usableFetchedProducts)
                relatedProductIDsByCategory[categoryKey] = usableFetchedProducts.map(\.id)
                loadedRelatedCategories.insert(categoryKey)
            } catch {
                return localProducts
            }
        }

        return RelatedProductRanker.products(
            for: product,
            explicitAlternatives: alternatives(for: product)
                + relatedProductIDsByCategory[categoryKey, default: []].compactMap { self.product(id: $0) },
            catalog: products,
            limit: limit
        )
    }

    func loadGoalRecommendations(for goals: [GroceryGoal], limit: Int) async {
        guard remoteEnabled, limit > 0, !goals.isEmpty, !isLoadingGoalRecommendations else { return }

        let goalsToLoad = goals.filter {
            let queryKey = $0.catalogSearchQuery.lowercased()
            let existingMatches = GroceryGoal.matchingProducts(
                in: products,
                filter: $0,
                preferredGoals: goals
            )
            return !loadedGoalQueries.contains(queryKey) && existingMatches.count < limit
        }
        guard !goalsToLoad.isEmpty else { return }

        isLoadingGoalRecommendations = true
        goalRecommendationsErrorMessage = nil
        defer { isLoadingGoalRecommendations = false }

        let service = openFoodFactsService
        let pageSize = min(30, max(limit, 12))
        let results = await withTaskGroup(
            of: GoalRecommendationResult.self,
            returning: [GoalRecommendationResult].self
        ) { group in
            var iterator = goalsToLoad.makeIterator()

            func addNextTask() {
                guard let goal = iterator.next() else { return }

                group.addTask {
                    do {
                        let fetchedProducts = try await service.searchProducts(
                            matching: goal.catalogSearchQuery,
                            pageSize: pageSize
                        )
                        return GoalRecommendationResult(
                            queryKey: goal.catalogSearchQuery.lowercased(),
                            products: fetchedProducts.filter {
                                $0.name != "Unknown product" && $0.imageURL != nil
                            },
                            succeeded: true
                        )
                    } catch {
                        return GoalRecommendationResult(
                            queryKey: goal.catalogSearchQuery.lowercased(),
                            products: [],
                            succeeded: false
                        )
                    }
                }
            }

            for _ in 0..<min(3, goalsToLoad.count) {
                addNextTask()
            }

            var completed: [GoalRecommendationResult] = []
            while let result = await group.next() {
                completed.append(result)
                addNextTask()
            }
            return completed
        }

        guard !Task.isCancelled else { return }

        let successfulResults = results.filter(\.succeeded)
        merge(successfulResults.flatMap(\.products))
        loadedGoalQueries.formUnion(successfulResults.map(\.queryKey))

        if successfulResults.isEmpty {
            goalRecommendationsErrorMessage = "Couldn't refresh goal matches. Check your connection and try again."
        }
    }

    func retryGoalRecommendations(for goals: [GroceryGoal], limit: Int) async {
        loadedGoalQueries.subtract(goals.map { $0.catalogSearchQuery.lowercased() })
        await loadGoalRecommendations(for: goals, limit: limit)
    }

    private struct GoalRecommendationResult: Sendable {
        let queryKey: String
        let products: [Product]
        let succeeded: Bool
    }

    private func merge(_ incomingProducts: [Product]) {
        guard !incomingProducts.isEmpty else { return }

        var merged = products
        var indexesByBarcode: [String: Int] = [:]
        for (index, product) in merged.enumerated() {
            indexesByBarcode[product.barcode] = index
        }

        for incomingProduct in incomingProducts {
            if let index = indexesByBarcode[incomingProduct.barcode] {
                merged[index] = incomingProduct
            } else {
                indexesByBarcode[incomingProduct.barcode] = merged.count
                merged.append(incomingProduct)
            }
        }

        products = merged
    }
}
