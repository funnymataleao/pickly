import Foundation

@MainActor
protocol ProductService {
    var products: [Product] { get }

    func searchProducts(matching query: String) -> [Product]
    func product(id: String) -> Product?
    func alternatives(for product: Product) -> [Product]
    func relatedProducts(for product: Product, limit: Int) async -> [Product]
}

protocol ProductLookupService {
    func fetchProduct(barcode: String) async throws -> Product
}

extension ProductService {
    func searchProducts(matching query: String) -> [Product] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else {
            return products
        }

        return products.filter { product in
            product.name.localizedCaseInsensitiveContains(trimmedQuery)
                || product.brand.localizedCaseInsensitiveContains(trimmedQuery)
                || product.category.localizedCaseInsensitiveContains(trimmedQuery)
                || product.barcode.contains(trimmedQuery)
        }
    }

    func product(id: String) -> Product? {
        products.first { $0.id == id }
    }

    func alternatives(for product: Product) -> [Product] {
        product.alternativeIDs.compactMap(product(id:))
    }

    func relatedProducts(for product: Product, limit: Int) async -> [Product] {
        RelatedProductRanker.products(
            for: product,
            explicitAlternatives: alternatives(for: product),
            catalog: products,
            limit: limit
        )
    }
}

enum RelatedProductRanker {
    static func products(
        for currentProduct: Product,
        explicitAlternatives: [Product],
        catalog: [Product],
        limit: Int
    ) -> [Product] {
        guard limit > 0 else { return [] }

        var seenIDs = Set([currentProduct.id])
        var result: [Product] = []

        func appendUnique(_ product: Product) {
            guard result.count < limit, seenIDs.insert(product.id).inserted else { return }
            result.append(product)
        }

        explicitAlternatives.forEach(appendUnique)

        let eligibleProducts = catalog.filter { product in
            product.name != "Unknown product"
                && (product.imageURL != nil || product.source == .mock)
                && categoriesAreRelated(product.category, currentProduct.category)
        }
        let currentScore = currentProduct.score
        let ranked = eligibleProducts.sorted { lhs, rhs in
            let lhsSameCategory = lhs.category.caseInsensitiveCompare(currentProduct.category) == .orderedSame
            let rhsSameCategory = rhs.category.caseInsensitiveCompare(currentProduct.category) == .orderedSame
            if lhsSameCategory != rhsSameCategory {
                return lhsSameCategory
            }

            let lhsDistance = scoreDistance(from: currentScore, to: lhs.score)
            let rhsDistance = scoreDistance(from: currentScore, to: rhs.score)
            if lhsDistance != rhsDistance {
                return lhsDistance < rhsDistance
            }

            return (lhs.score ?? -1) > (rhs.score ?? -1)
        }

        ranked.forEach(appendUnique)
        return result
    }

    private static func scoreDistance(from currentScore: Int?, to candidateScore: Int?) -> Int {
        guard let currentScore, let candidateScore else { return .max }
        return abs(currentScore - candidateScore)
    }

    private static func categoriesAreRelated(_ lhs: String, _ rhs: String) -> Bool {
        let lhsTokens = categoryTokens(lhs)
        let rhsTokens = categoryTokens(rhs)
        return !lhsTokens.isDisjoint(with: rhsTokens)
    }

    private static func categoryTokens(_ category: String) -> Set<String> {
        let ignoredTokens = Set(["food", "foods", "product", "products", "grocery", "groceries"])
        let tokens = category
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 2 && !ignoredTokens.contains($0) }
        return Set(tokens)
    }
}
