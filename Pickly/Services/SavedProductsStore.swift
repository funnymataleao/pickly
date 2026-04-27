import Foundation
import Combine

final class SavedProductsStore: ObservableObject {
    @Published private(set) var savedProducts: [SavedProduct] = []

    func isSaved(_ product: Product) -> Bool {
        savedProducts.contains { $0.productId == product.id }
    }

    func toggle(_ product: Product) {
        if let index = savedProducts.firstIndex(where: { $0.productId == product.id }) {
            savedProducts.remove(at: index)
        } else {
            savedProducts.insert(SavedProduct(productId: product.id, date: .now), at: 0)
        }
    }
}
