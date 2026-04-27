import SwiftUI

struct SearchView: View {
    let productService: MockProductService
    @ObservedObject var savedStore: SavedProductsStore
    let preferences: UserPreferences

    @State private var query = ""

    private var products: [Product] {
        productService.searchProducts(matching: query)
    }

    var body: some View {
        List {
            Section {
                HeaderView()
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowBackground(Color.clear)
            }

            Section("Products") {
                ForEach(products) { product in
                    NavigationLink(value: product) {
                        ProductRowView(
                            product: product,
                            isSaved: savedStore.isSaved(product)
                        )
                    }
                    .accessibilityLabel("\(product.name), \(product.brand), \(product.verdict), score \(product.score)")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Search products")
        .searchable(text: $query, prompt: "Search products")
        .overlay {
            if products.isEmpty {
                ContentUnavailableView(
                    "No products found",
                    systemImage: "magnifyingglass",
                    description: Text("Try a product name, brand, category, or barcode.")
                )
            }
        }
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

private struct HeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(.green)

                Text("Pickly")
                    .font(.largeTitle.bold())
            }

            Text("Scan better. Choose smarter.")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Search the mock grocery list and open a product to see a clear score, simple explanation, and better alternatives.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.green.opacity(0.1))
        )
    }
}

#Preview {
    NavigationStack {
        SearchView(
            productService: MockProductService(),
            savedStore: SavedProductsStore(),
            preferences: .prototype
        )
    }
}
