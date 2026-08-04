import Combine
import Foundation

@MainActor
final class SavedProductsStore: ObservableObject {
    @Published private(set) var savedProducts: [SavedProduct]
    @Published private(set) var recentProducts: [SavedProduct]

    private var productSnapshots: [String: Product]
    private let maxRecentProducts = 30
    private let defaults: UserDefaults
    private let storageKey = "pickly.saved-products.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: storageKey),
           let state = try? JSONDecoder().decode(SavedProductsState.self, from: data) {
            savedProducts = state.savedProducts
            recentProducts = state.recentProducts
            productSnapshots = state.productSnapshots
        } else {
            savedProducts = []
            recentProducts = []
            productSnapshots = [:]
        }
    }

    func isSaved(_ product: Product) -> Bool {
        savedProducts.contains { $0.productId == product.id }
    }

    func product(id: String) -> Product? {
        productSnapshots[id]
    }

    func recordView(_ product: Product) {
        productSnapshots[product.id] = product
        recentProducts.removeAll { $0.productId == product.id }
        recentProducts.insert(SavedProduct(productId: product.id, date: .now), at: 0)

        if recentProducts.count > maxRecentProducts {
            recentProducts.removeLast(recentProducts.count - maxRecentProducts)
        }

        persist()
    }

    func toggle(_ product: Product) {
        if let index = savedProducts.firstIndex(where: { $0.productId == product.id }) {
            savedProducts.remove(at: index)
        } else {
            productSnapshots[product.id] = product
            savedProducts.insert(SavedProduct(productId: product.id, date: .now), at: 0)
        }

        persist()
    }

    func clearLocalData() {
        savedProducts.removeAll()
        recentProducts.removeAll()
        productSnapshots.removeAll()
        defaults.removeObject(forKey: storageKey)
    }

    private func persist() {
        let state = SavedProductsState(
            savedProducts: savedProducts,
            recentProducts: recentProducts,
            productSnapshots: productSnapshots
        )

        guard let data = try? JSONEncoder().encode(state) else {
            return
        }

        defaults.set(data, forKey: storageKey)
    }
}

private struct SavedProductsState: Codable {
    let savedProducts: [SavedProduct]
    let recentProducts: [SavedProduct]
    let productSnapshots: [String: Product]
}
