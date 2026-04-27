import SwiftUI

struct SavedView: View {
    let productService: MockProductService
    @ObservedObject var savedStore: SavedProductsStore
    let preferences: UserPreferences

    private var savedProducts: [Product] {
        savedStore.savedProducts.compactMap { savedProduct in
            productService.product(id: savedProduct.productId)
        }
    }

    var body: some View {
        List {
            if savedProducts.isEmpty {
                ContentUnavailableView(
                    "No saved products",
                    systemImage: "bookmark",
                    description: Text("Save a product from the result screen to see it here.")
                )
                .listRowBackground(Color.clear)
            } else {
                Section("Saved") {
                    ForEach(savedProducts) { product in
                        NavigationLink(value: product) {
                            ProductRowView(product: product, isSaved: true)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Saved")
        .navigationDestination(for: Product.self) { product in
            ProductResultView(
                product: product,
                productService: productService,
                savedStore: savedStore,
                preferences: preferences
            )
        }
    }
}

#Preview {
    NavigationStack {
        SavedView(
            productService: MockProductService(),
            savedStore: SavedProductsStore(),
            preferences: .prototype
        )
    }
}
