import Foundation

protocol ProductService {
    var products: [Product] { get }

    func searchProducts(matching query: String) -> [Product]
    func product(id: String) -> Product?
    func alternatives(for product: Product) -> [Product]
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
}
