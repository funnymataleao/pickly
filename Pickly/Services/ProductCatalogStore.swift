import Combine
import Foundation

@MainActor
final class ProductCatalogStore: ObservableObject, ProductService, ProductLookupService {
    enum CatalogError: LocalizedError {
        case notFound

        var errorDescription: String? {
            switch self {
            case .notFound:
                PicklyCopy.localized("Product not found.")
            }
        }
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var loadingGoalRecommendations = Set<GroceryGoal>()
    @Published private(set) var goalRecommendationErrors: [GroceryGoal: String] = [:]
    @Published private(set) var goalRecommendationProductIDs: [GroceryGoal: [String]] = [:]
    @Published private(set) var goalRecommendationTotals: [GroceryGoal: Int] = [:]
    @Published private(set) var goalRecommendationPages: [GroceryGoal: Int] = [:]
    @Published private(set) var goalsWithMoreRecommendations = Set<GroceryGoal>()
    @Published private(set) var errorMessage: String?
    @Published private(set) var relatedProductsErrorMessage: String?
    @Published private(set) var hasLoaded = false

    private let catalogService: CloudflareProductService
    private let openFoodFactsService: OpenFoodFactsService
    private let localeContext: PicklyLocaleContext
    private let fallbackProducts: [Product]
    private let remoteEnabled: Bool
    private let prototypeFallbackEnabled: Bool
    private var loadedQueries = Set<String>()
    private var loadedRelatedCategories = Set<String>()
    private var relatedProductIDsByCategory: [String: [String]] = [:]
    private var loadedGoalQueries = Set<GroceryGoal>()
    private var goalLoadTasks: [GroceryGoal: Task<Void, Never>] = [:]
    private var attemptedFactEnrichmentBarcodes = Set<String>()

    var isLoadingGoalRecommendations: Bool {
        !loadingGoalRecommendations.isEmpty
    }

    var goalRecommendationsErrorMessage: String? {
        goalRecommendationErrors.values.first
    }

    init(
        catalogService: CloudflareProductService,
        openFoodFactsService: OpenFoodFactsService? = nil,
        fallbackProducts: [Product]? = nil,
        remoteEnabled: Bool? = nil,
        prototypeFallbackEnabled: Bool? = nil,
        localeContext: PicklyLocaleContext = .current
    ) {
        self.localeContext = localeContext
        self.catalogService = catalogService
        self.openFoodFactsService = openFoodFactsService ?? OpenFoodFactsService(
            goalProxyBaseURL: PicklyAPIConfiguration.baseURL,
            localeContext: localeContext
        )
        let resolvedFallbackProducts = (fallbackProducts ?? MockProductService().products)
            .map { $0.localizedPresentation(localeContext: localeContext) }
        let resolvedRemoteEnabled = remoteEnabled ?? PicklyAPIConfiguration.isConfigured
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

    convenience init(
        openFoodFactsService: OpenFoodFactsService? = nil,
        fallbackProducts: [Product]? = nil,
        remoteEnabled: Bool? = nil,
        prototypeFallbackEnabled: Bool? = nil,
        localeContext: PicklyLocaleContext = .current
    ) {
        self.init(
            catalogService: CloudflareProductService(localeContext: localeContext),
            openFoodFactsService: openFoodFactsService,
            fallbackProducts: fallbackProducts,
            remoteEnabled: remoteEnabled,
            prototypeFallbackEnabled: prototypeFallbackEnabled,
            localeContext: localeContext
        )
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
                errorMessage = PicklyCopy.localized("Product catalog is not configured for this build yet.")
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
            let remoteProducts = try await catalogService.fetchPublishedProducts()
            if remoteProducts.isEmpty {
                products = []
                errorMessage = PicklyCopy.localized("No catalog products are available right now.")
            } else {
                merge(remoteProducts)
            }
        } catch {
            products = []
            errorMessage = PicklyCopy.localized("Couldn't load product data. Check your connection and try again.")
        }
    }

    func search(query: String) async {
        let normalizedQuery = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let cacheKey = "\(localeContext.language.rawValue)|\(localeContext.regionCode)|\(normalizedQuery)"

        guard normalizedQuery.count >= 2 else {
            return
        }

        guard remoteEnabled else {
            if !prototypeFallbackEnabled {
                errorMessage = PicklyCopy.localized("Product catalog is not configured for this build yet.")
            }
            return
        }

        guard !loadedQueries.contains(cacheKey) else {
            return
        }

        if !searchProducts(matching: normalizedQuery).isEmpty {
            loadedQueries.insert(cacheKey)
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let catalogProducts = try await catalogService.searchPublishedProducts(matching: query)
            merge(catalogProducts)

            if catalogProducts.isEmpty {
                let fetchedProducts = try await openFoodFactsService.searchProducts(matching: query)
                merge(fetchedProducts)
            }

            loadedQueries.insert(cacheKey)
        } catch let error as OpenFoodFactsService.ServiceError {
            errorMessage = error.errorDescription
        } catch {
            do {
                let fetchedProducts = try await openFoodFactsService.searchProducts(matching: query)
                merge(fetchedProducts)
                loadedQueries.insert(cacheKey)
            } catch let error as OpenFoodFactsService.ServiceError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = PicklyCopy.localized("Couldn't load product data. Check your connection and try again.")
            }
        }
    }

    func fetchProduct(barcode: String) async throws -> Product {
        if let localProduct = products.first(where: { $0.barcode == barcode }) {
            let enrichedProduct = await enrichFactsIfNeeded(for: localProduct)
            merge([enrichedProduct])
            return enrichedProduct
        }

        guard remoteEnabled else {
            throw CatalogError.notFound
        }

        do {
            if let remoteProduct = try await catalogService.fetchProduct(barcode: barcode) {
                let enrichedProduct = await enrichFactsIfNeeded(for: remoteProduct)
                merge([enrichedProduct])
                return enrichedProduct
            }
        } catch {
            // A cache miss or a temporary catalog failure falls back to Open Food Facts.
        }

        let fetchedProduct = try await openFoodFactsService.fetchProduct(barcode: barcode)
        merge([fetchedProduct])
        return fetchedProduct
    }

    private func enrichFactsIfNeeded(for product: Product) async -> Product {
        guard
            remoteEnabled,
            product.source != .mock,
            attemptedFactEnrichmentBarcodes.insert(product.barcode).inserted
        else {
            return product
        }

        do {
            let openFoodFactsProduct = try await openFoodFactsService.fetchProduct(
                barcode: product.barcode
            )
            return product.mergingCatalogData(from: openFoodFactsProduct)
        } catch is CancellationError {
            return product
        } catch {
            // The curated catalog remains usable when community metadata is
            // unavailable or the barcode has no Open Food Facts record.
            return product
        }
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
                !ProductIdentity.isSame(candidate, as: product)
                    && ProductSimilarity.isComparable(candidate, to: product)
                    && !candidate.isLimitedData
                    && (candidate.score ?? 0) > score
            }
            .sorted { ($0.score ?? 0) > ($1.score ?? 0) }
            .prefix(8)
            .map { $0 }
    }

    func relatedProducts(for product: Product, limit: Int) async -> [Product] {
        relatedProductsErrorMessage = nil
        let searchTexts = RelatedProductQuery.searchTexts(for: product)
        let categoryTags = RelatedProductQuery.categoryTags(for: product)
        let marketCountryTags = localeContext.preferredCountryTags
        // Reuse one fetched pool across products from the same semantic family.
        // Using the full product name here caused every tapped card to launch
        // another three network searches while the navigation transition ran.
        let categoryKey = RelatedProductQuery.cacheKey(for: product)
            + "|language:\(localeContext.language.rawValue)|markets:\(marketCountryTags.joined(separator: ","))"
        let fetchedMatches = relatedProductIDsByCategory[categoryKey, default: []]
            .compactMap { self.product(id: $0) }
        let explicitLocalAlternatives = product.alternativeIDs.compactMap { self.product(id: $0) }
            + fetchedMatches
        let catalogSnapshot = products
        let localProducts = await Self.rankRelatedProducts(
            for: product,
            explicitAlternatives: explicitLocalAlternatives,
            catalog: catalogSnapshot,
            limit: limit
        )
        guard !Task.isCancelled else { return localProducts }
        guard limit > localProducts.count, remoteEnabled else {
            return localProducts
        }

        guard !categoryKey.isEmpty else { return localProducts }

        if !loadedRelatedCategories.contains(categoryKey) {
            var fetchedProducts: [Product] = []
            var completedSearch = false
            var encounteredFailure = false

            // Better Choices is a paid trust surface: only canonical OFF
            // taxonomy is allowed for live products. Prefer the user's market,
            // then an English market, then the global catalog.
            let countryTiers: [String?] = marketCountryTags.map(Optional.some) + [nil]
            for countryTag in countryTiers {
                for categoryTag in categoryTags {
                    var page = 1
                    let maximumPages = min(5, max(2, Int(ceil(Double(limit) / 50.0)) + 2))
                    while page <= maximumPages {
                        guard !Task.isCancelled else { return localProducts }
                        do {
                            let resultPage = try await openFoodFactsService.searchProductPage(
                                categoryTag: categoryTag,
                                pageSize: 50,
                                page: page,
                                countryTag: countryTag
                            )
                            completedSearch = true
                            fetchedProducts.append(contentsOf: resultPage.products)

                            if Self.usableRelatedCandidates(in: fetchedProducts, for: product).count >= limit
                                || !resultPage.hasMore {
                                break
                            }
                            page = max(page + 1, resultPage.page + 1)
                        } catch {
                            encounteredFailure = true
                            break
                        }
                    }

                    if Self.usableRelatedCandidates(in: fetchedProducts, for: product).count >= limit {
                        break
                    }
                }

                if Self.usableRelatedCandidates(in: fetchedProducts, for: product).count >= limit {
                    break
                }
            }

            // Text fallback is permitted only for local fixtures/curated data.
            // A live OFF product without trustworthy taxonomy fails closed.
            if categoryTags.isEmpty,
               product.source != .openFoodFacts,
               Self.usableRelatedCandidates(in: fetchedProducts, for: product).count < limit {
                for query in searchTexts {
                    guard !Task.isCancelled else { return localProducts }
                    let queryProducts: [Product]
                    do {
                        queryProducts = try await openFoodFactsService.searchProducts(
                            matching: query,
                            pageSize: 50
                        )
                        completedSearch = true
                    } catch {
                        encounteredFailure = true
                        continue
                    }
                    guard !Task.isCancelled else { return localProducts }
                    fetchedProducts.append(contentsOf: queryProducts)

                    if Self.usableRelatedCandidates(in: fetchedProducts, for: product).count >= limit {
                        break
                    }
                }
            }

            var seenKeys = Set<String>()
            let usableFetchedProducts = fetchedProducts.filter {
                $0.name != "Unknown product"
                    && $0.imageURL != nil
                    && seenKeys.insert(ProductIdentity.key(for: $0)).inserted
            }
            let comparableFetchedProducts = Self.usableRelatedCandidates(
                in: usableFetchedProducts,
                for: product
            )
            let canonicalIDs = merge(comparableFetchedProducts)
            var seenCanonicalIDs = Set<String>()
            relatedProductIDsByCategory[categoryKey] = comparableFetchedProducts.compactMap {
                let canonicalID = canonicalIDs[$0.id] ?? $0.id
                return seenCanonicalIDs.insert(canonicalID).inserted ? canonicalID : nil
            }
            if completedSearch, !encounteredFailure, !comparableFetchedProducts.isEmpty {
                loadedRelatedCategories.insert(categoryKey)
            }
            if encounteredFailure || !completedSearch {
                relatedProductsErrorMessage = PicklyCopy.localized("The product catalog is temporarily unavailable. Check your connection and try again.")
            }
        }

        guard !Task.isCancelled else { return localProducts }
        let updatedExplicitAlternatives = product.alternativeIDs.compactMap { self.product(id: $0) }
            + relatedProductIDsByCategory[categoryKey, default: []].compactMap { self.product(id: $0) }
        let updatedCatalogSnapshot = products
        return await Self.rankRelatedProducts(
            for: product,
            explicitAlternatives: updatedExplicitAlternatives,
            catalog: updatedCatalogSnapshot,
            limit: limit
        )
    }

    private nonisolated static func rankRelatedProducts(
        for product: Product,
        explicitAlternatives: [Product],
        catalog: [Product],
        limit: Int
    ) async -> [Product] {
        await Task.detached(priority: .userInitiated) {
            RelatedProductRanker.products(
                for: product,
                explicitAlternatives: explicitAlternatives,
                catalog: catalog,
                limit: limit
            )
        }.value
    }

    private nonisolated static func usableRelatedCandidates(
        in products: [Product],
        for currentProduct: Product
    ) -> [Product] {
        var seenIDs = Set<String>()
        return products.filter { candidate in
            candidate.id != currentProduct.id
                && candidate.barcode != currentProduct.barcode
                && candidate.name != "Unknown product"
                && candidate.imageURL != nil
                && !candidate.isLimitedData
                && ProductSimilarity.isComparable(candidate, to: currentProduct)
                && seenIDs.insert(candidate.id).inserted
        }
    }

    func goalProducts(
        for filter: GroceryGoal,
        preferredGoals: [GroceryGoal]
    ) -> [Product] {
        let sourceGoals = filter == .all ? preferredGoals : [filter]
        var seenIDs = Set<String>()
        let scopedProducts = sourceGoals
            .flatMap { goalRecommendationProductIDs[$0, default: []] }
            .compactMap { product(id: $0) }
            .filter { seenIDs.insert($0.id).inserted }

        if !scopedProducts.isEmpty {
            if filter == .all {
                return GroceryGoal.healthiestMatchingProducts(
                    in: scopedProducts,
                    filter: filter,
                    preferredGoals: preferredGoals
                )
            }

            return GroceryGoal.rankedFeedProducts(
                in: scopedProducts,
                for: filter
            )
        }

        let relevantGoals = Set(sourceGoals)
        let hasScopedFailure = relevantGoals.contains { goalRecommendationErrors[$0] != nil }
        guard !hasScopedFailure, !remoteEnabled else { return [] }

        // Preview and explicit offline fixtures can still exercise the goal UI
        // without networking. A live build never substitutes its shared base
        // catalog for a goal-specific Open Food Facts feed.
        return GroceryGoal.healthiestMatchingProducts(
            in: products,
            filter: filter,
            preferredGoals: preferredGoals
        )
    }

    func isLoadingGoalRecommendation(
        for filter: GroceryGoal,
        preferredGoals: [GroceryGoal]
    ) -> Bool {
        let relevantGoals = filter == .all ? preferredGoals : [filter]
        return relevantGoals.contains { loadingGoalRecommendations.contains($0) }
    }

    func goalRecommendationError(
        for filter: GroceryGoal,
        preferredGoals: [GroceryGoal]
    ) -> String? {
        let relevantGoals = filter == .all ? preferredGoals : [filter]
        return relevantGoals.compactMap { goalRecommendationErrors[$0] }.first
    }

    func goalRecommendationTotal(
        for filter: GroceryGoal,
        preferredGoals: [GroceryGoal]
    ) -> Int? {
        if filter != .all {
            return goalRecommendationTotals[filter]
        }

        let totals = preferredGoals.compactMap { goalRecommendationTotals[$0] }
        return totals.isEmpty ? nil : totals.reduce(0, +)
    }

    func hasMoreGoalRecommendations(for goal: GroceryGoal) -> Bool {
        goalsWithMoreRecommendations.contains(goal)
    }

    func loadGoalRecommendations(for goals: [GroceryGoal], limit: Int) async {
        guard remoteEnabled, limit > 0 else { return }

        // Keep requests sequential to respect Open Food Facts rate limits, but
        // persist every goal page immediately so cancellation cannot erase the
        // successful feeds loaded before it.
        for goal in goals where goal != .all {
            guard !Task.isCancelled else { return }
            await enqueueGoalRecommendationLoad(
                for: goal,
                targetCount: limit,
                maximumPages: limit > 50 ? 4 : 3
            )
        }
    }

    func loadMoreGoalRecommendations(for goal: GroceryGoal, pageSize: Int = 24) async {
        guard goal != .all, goalsWithMoreRecommendations.contains(goal) else { return }
        let currentCount = goalRecommendationProductIDs[goal, default: []].count
        await enqueueGoalRecommendationLoad(
            for: goal,
            targetCount: currentCount + max(1, min(pageSize, 24)),
            maximumPages: 1
        )
    }

    func retryGoalRecommendations(for goals: [GroceryGoal], limit: Int) async {
        for goal in goals where goal != .all {
            loadedGoalQueries.remove(goal)
            goalRecommendationErrors.removeValue(forKey: goal)
            goalRecommendationProductIDs.removeValue(forKey: goal)
            goalRecommendationTotals.removeValue(forKey: goal)
            goalRecommendationPages.removeValue(forKey: goal)
            goalsWithMoreRecommendations.remove(goal)
        }
        await loadGoalRecommendations(for: goals, limit: limit)
    }

    private func enqueueGoalRecommendationLoad(
        for goal: GroceryGoal,
        targetCount: Int,
        maximumPages: Int
    ) async {
        while true {
            if let existingTask = goalLoadTasks[goal] {
                await existingTask.value
                guard !Task.isCancelled,
                      goalRecommendationErrors[goal] == nil,
                      goalRecommendationProductIDs[goal, default: []].count < targetCount,
                      goalsWithMoreRecommendations.contains(goal) else {
                    return
                }
                continue
            }

            let loadTask = Task { @MainActor [weak self] in
                guard let self else { return }
                await self.performGoalRecommendationLoad(
                    for: goal,
                    targetCount: targetCount,
                    maximumPages: maximumPages
                )
            }
            goalLoadTasks[goal] = loadTask
            await loadTask.value
            goalLoadTasks.removeValue(forKey: goal)
            return
        }
    }

    private func performGoalRecommendationLoad(
        for goal: GroceryGoal,
        targetCount: Int,
        maximumPages: Int
    ) async {
        let existingCount = goalRecommendationProductIDs[goal, default: []].count
        guard remoteEnabled,
              targetCount > 0,
              maximumPages > 0,
              !loadingGoalRecommendations.contains(goal),
              existingCount < targetCount,
              !loadedGoalQueries.contains(goal) || goalsWithMoreRecommendations.contains(goal) else {
            return
        }

        loadingGoalRecommendations.insert(goal)
        goalRecommendationErrors.removeValue(forKey: goal)
        defer { loadingGoalRecommendations.remove(goal) }

        let pageSize = 24
        var nextPage = goalRecommendationPages[goal, default: 0] + 1
        var pagesLoaded = 0
        var loadedAnyPage = false

        while goalRecommendationProductIDs[goal, default: []].count < targetCount,
              pagesLoaded < maximumPages {
            guard !Task.isCancelled else { return }

            let resultPage: OpenFoodFactsProductPage
            do {
                resultPage = try await openFoodFactsService.searchProductPage(
                    for: goal,
                    pageSize: pageSize,
                    page: nextPage,
                    languageCode: localeContext.openFoodFactsLanguageCode
                )
            } catch {
                guard !Task.isCancelled else { return }
                goalRecommendationErrors[goal] = PicklyCopy.format(
                    "Couldn't refresh %@ products. Check your connection and try again.",
                    goal.title.lowercased()
                )
                return
            }

            guard !Task.isCancelled else { return }
            loadedAnyPage = true
            pagesLoaded += 1
            goalRecommendationTotals[goal] = resultPage.totalCount
            goalRecommendationPages[goal] = resultPage.page

            let usableProducts = resultPage.products.filter {
                $0.name != "Unknown product"
                    && $0.imageURL != nil
                    && goal.matches($0)
            }
            let canonicalIDs = merge(usableProducts)

            var orderedIDs = goalRecommendationProductIDs[goal, default: []]
            var seenIDs = Set(orderedIDs)
            for product in usableProducts {
                let canonicalID = canonicalIDs[product.id] ?? product.id
                if seenIDs.insert(canonicalID).inserted {
                    orderedIDs.append(canonicalID)
                }
            }
            goalRecommendationProductIDs[goal] = orderedIDs

            if resultPage.hasMore {
                goalsWithMoreRecommendations.insert(goal)
            } else {
                goalsWithMoreRecommendations.remove(goal)
                break
            }

            nextPage = resultPage.page + 1
        }

        if loadedAnyPage,
           (!goalRecommendationProductIDs[goal, default: []].isEmpty
               || !goalsWithMoreRecommendations.contains(goal)) {
            loadedGoalQueries.insert(goal)
        }
    }

    @discardableResult
    private func merge(_ incomingProducts: [Product]) -> [String: String] {
        guard !incomingProducts.isEmpty else { return [:] }

        var merged = products
        var indexesByBarcode: [String: Int] = [:]
        var canonicalIDs: [String: String] = [:]
        for (index, product) in merged.enumerated() {
            indexesByBarcode[product.barcode] = index
        }

        for incomingProduct in incomingProducts {
            if let index = indexesByBarcode[incomingProduct.barcode] {
                let existingID = merged[index].id
                merged[index] = merged[index].mergingCatalogData(from: incomingProduct)
                canonicalIDs[incomingProduct.id] = existingID
            } else {
                indexesByBarcode[incomingProduct.barcode] = merged.count
                merged.append(incomingProduct)
                canonicalIDs[incomingProduct.id] = incomingProduct.id
            }
        }

        products = merged
        return canonicalIDs
    }
}
