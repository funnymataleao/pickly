import SwiftUI

struct SavedView: View {
    let productService: any ProductService
    @ObservedObject var savedStore: SavedProductsStore
    let preferences: UserPreferences

    @State private var selectedList = SavedList.saved
    @State private var selectedProduct: Product?

    private var savedProducts: [Product] {
        savedStore.savedProducts.compactMap { savedProduct in
            savedStore.product(id: savedProduct.productId) ?? productService.product(id: savedProduct.productId)
        }
    }

    private var recentProducts: [Product] {
        savedStore.recentProducts.compactMap { recentProduct in
            savedStore.product(id: recentProduct.productId) ?? productService.product(id: recentProduct.productId)
        }
    }

    private var visibleProducts: [Product] {
        switch selectedList {
        case .saved:
            return savedProducts
        case .history:
            return recentProducts
        }
    }

    var body: some View {
        List {
            PicklyContentHeader(title: "Saved")
                .picklyContentHeaderRow()

            Section {
                Picker("List", selection: $selectedList) {
                    ForEach(SavedList.allCases) { list in
                        Text(list.title).tag(list)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            }
            .listRowBackground(Color.clear)

            if visibleProducts.isEmpty {
                SavedEmptyStateCard(
                    systemImage: selectedList.emptySystemImage,
                    title: selectedList.emptyTitle,
                    message: selectedList.emptyDescription
                )
                .picklyListCardRow(top: 12, bottom: 14)
            } else {
                Section(selectedList.title) {
                    ProductRowsCard(
                        products: visibleProducts,
                        isSaved: { product in
                            savedStore.isSaved(product)
                        },
                        accessibilityLabel: accessibilityLabel(for:),
                        onSelect: { product in
                            selectedProduct = product
                        }
                    )
                    .picklyListCardRow()
                }
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.top, PicklyLayout.rootTopPadding, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background(PicklyColor.background)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $selectedProduct) { product in
            ProductResultView(
                product: product,
                productService: productService,
                savedStore: savedStore,
                preferences: preferences
            )
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

    private func accessibilityLabel(for product: Product) -> String {
        if !product.isLimitedData, let score = product.score {
            return "\(product.name), \(product.brand), \(product.verdict), score \(score)"
        }

        return "\(product.name), \(product.brand), Limited data"
    }
}

private struct SavedEmptyStateCard: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(PicklyColor.primary)
                .frame(width: 56, height: 56)
                .background(PicklyColor.mint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .picklyCardSurface(cornerRadius: 22)
        .accessibilityElement(children: .combine)
    }
}

private enum SavedList: String, CaseIterable, Identifiable {
    case saved
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .saved:
            return "Saved"
        case .history:
            return "History"
        }
    }

    var emptyTitle: String {
        switch self {
        case .saved:
            return "No saved products"
        case .history:
            return "No recent products"
        }
    }

    var emptyDescription: String {
        switch self {
        case .saved:
            return "Save a product from the result screen to see it here."
        case .history:
            return "Open a product result to build your recent list."
        }
    }

    var emptySystemImage: String {
        switch self {
        case .saved:
            return "bookmark"
        case .history:
            return "clock"
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
