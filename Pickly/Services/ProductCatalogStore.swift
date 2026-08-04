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
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasLoaded = false

    private let supabaseService: SupabaseProductService
    private let openFoodFactsService: OpenFoodFactsService
    private let fallbackProducts: [Product]
    private let remoteEnabled: Bool
    private var loadedQueries = Set<String>()

    init(
        supabaseService: SupabaseProductService = SupabaseProductService(),
        openFoodFactsService: OpenFoodFactsService = OpenFoodFactsService(),
        fallbackProducts: [Product] = [],
        remoteEnabled: Bool = true
    ) {
        self.supabaseService = supabaseService
        self.openFoodFactsService = openFoodFactsService
        self.fallbackProducts = fallbackProducts
        self.remoteEnabled = remoteEnabled
        self.products = remoteEnabled ? [] : fallbackProducts
        self.hasLoaded = !remoteEnabled
    }

    static var preview: ProductCatalogStore {
        ProductCatalogStore(
            fallbackProducts: MockProductService().products,
            remoteEnabled: false
        )
    }

    func loadInitial() async {
        guard !hasLoaded, !isLoading else { return }

        guard remoteEnabled else {
            products = fallbackProducts
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
            merge(remoteProducts)
        } catch {
            errorMessage = "Couldn't load the saved catalog. You can still search or scan a barcode."
        }
    }

    func search(query: String) async {
        let normalizedQuery = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard remoteEnabled, normalizedQuery.count >= 2 else {
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
            .prefix(3)
            .map { $0 }
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
