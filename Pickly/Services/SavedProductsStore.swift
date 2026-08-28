import Combine
import Foundation

@MainActor
final class SavedProductsStore: ObservableObject {
    @Published private(set) var savedProducts: [SavedProduct]
    @Published private(set) var recentProducts: [SavedProduct]

    private var productSnapshots: [String: Product]
    private let maxRecentProducts = 30
    private let defaults: UserDefaults
    private let defaultsBox: SendableUserDefaults
    private let localeContext: PicklyLocaleContext
    private let storageKey = "pickly.saved-products.v1"
    private let persistenceQueue = DispatchQueue(
        label: "com.pickly.saved-products.persistence",
        qos: .utility
    )

    init(
        defaults: UserDefaults = .standard,
        localeContext: PicklyLocaleContext = .current
    ) {
        self.defaults = defaults
        self.defaultsBox = SendableUserDefaults(defaults)
        self.localeContext = localeContext

        if let data = defaults.data(forKey: storageKey),
           let state = try? JSONDecoder().decode(SavedProductsState.self, from: data) {
            savedProducts = state.savedProducts
            recentProducts = state.recentProducts
            productSnapshots = state.productSnapshots.mapValues { snapshot in
                Self.localizedSnapshot(snapshot, localeContext: localeContext)
            }
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
        productSnapshots[product.id] = Self.localizedSnapshot(product, localeContext: localeContext)
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
            productSnapshots[product.id] = Self.localizedSnapshot(product, localeContext: localeContext)
            savedProducts.insert(SavedProduct(productId: product.id, date: .now), at: 0)
        }

        persist()
    }

    /// Reconciles durable Saved/History snapshots with the current catalog
    /// without changing the user's saved IDs, dates, or ordering. Barcode
    /// matching also upgrades legacy `off-<barcode>` snapshots to fresh D1 data.
    func refreshSnapshots(from catalogProducts: [Product]) {
        guard !productSnapshots.isEmpty else { return }

        var catalogByID: [String: Product] = [:]
        var catalogByBarcode: [String: Product] = [:]
        for product in catalogProducts {
            catalogByID[product.id] = product
            if let barcode = BarcodeValidator.normalize(product.barcode),
               catalogByBarcode[barcode] == nil {
                catalogByBarcode[barcode] = product
            }
        }

        var refreshedSnapshots = productSnapshots
        for (snapshotID, snapshot) in productSnapshots {
            let normalizedBarcode = BarcodeValidator.normalize(snapshot.barcode)
            let freshProduct = catalogByID[snapshotID]
                ?? normalizedBarcode.flatMap { catalogByBarcode[$0] }
            let refreshed = freshProduct.map { snapshot.mergingCatalogData(from: $0) } ?? snapshot
            refreshedSnapshots[snapshotID] = Self.localizedSnapshot(refreshed, localeContext: localeContext)
        }

        guard refreshedSnapshots != productSnapshots else { return }
        productSnapshots = refreshedSnapshots
        persist()
    }

    func clearLocalData() {
        savedProducts.removeAll()
        recentProducts.removeAll()
        productSnapshots.removeAll()

        let defaultsBox = defaultsBox
        let storageKey = storageKey
        persistenceQueue.async {
            defaultsBox.value.removeObject(forKey: storageKey)
        }
    }

    private func persist() {
        let state = SavedProductsState(
            savedProducts: savedProducts,
            recentProducts: recentProducts,
            productSnapshots: productSnapshots
        )

        let defaultsBox = defaultsBox
        let storageKey = storageKey
        persistenceQueue.async {
            guard let data = try? JSONEncoder().encode(state) else {
                return
            }

            defaultsBox.value.set(data, forKey: storageKey)
        }
    }

    /// Used by lifecycle coordination and tests that need durable state before
    /// constructing a fresh store. UI interactions never wait for this queue.
    func waitForPendingPersistence() async {
        await withCheckedContinuation { continuation in
            persistenceQueue.async {
                continuation.resume()
            }
        }
    }

    private nonisolated static func localizedSnapshot(
        _ product: Product,
        localeContext: PicklyLocaleContext
    ) -> Product {
        let displayProduct: Product
        if localeContext.language == .en {
            displayProduct = product.replacingName(
                with: EnglishProductNameResolver.displayName(for: product)
            )
        } else {
            displayProduct = product
        }
        return displayProduct.localizedPresentation(localeContext: localeContext)
    }

}

private nonisolated struct SavedProductsState: Codable, Sendable {
    let savedProducts: [SavedProduct]
    let recentProducts: [SavedProduct]
    let productSnapshots: [String: Product]
}

private nonisolated final class SendableUserDefaults: @unchecked Sendable {
    let value: UserDefaults

    init(_ value: UserDefaults) {
        self.value = value
    }
}
