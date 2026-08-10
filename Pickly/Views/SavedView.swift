import SwiftUI

struct SavedView: View {
    let productService: any ProductService
    @ObservedObject var savedStore: SavedProductsStore
    let preferences: UserPreferences
    var onScanAnotherProduct: (() -> Void)? = nil

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
        ScrollView {
            LazyVStack(spacing: 12) {
                Picker("Saved products list", selection: $selectedList) {
                    ForEach(SavedList.allCases) { list in
                        Text(list.title)
                            .tag(list)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityHint("Switches between saved products and product history.")
                .padding(.bottom, 4)

                if visibleProducts.isEmpty {
                    SavedEmptyStateCard(
                        systemImage: selectedList.emptySystemImage,
                        title: selectedList.emptyTitle,
                        message: selectedList.emptyDescription
                    )
                    .padding(.top, 8)
                } else {
                    ForEach(visibleProducts) { product in
                        ProductSummaryCard(
                            product: product,
                            reason: summaryReason(for: product),
                            isSaved: savedStore.isSaved(product),
                            onToggleSave: {
                                savedStore.toggle(product)
                            },
                            accessibilityLabel: accessibilityLabel(for: product),
                            onSelect: {
                                selectedProduct = product
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, PicklyLayout.screenHorizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .scrollClipDisabled()
        .background(PicklyColor.background)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $selectedProduct) { product in
            ProductResultView(
                product: product,
                productService: productService,
                savedStore: savedStore,
                preferences: preferences,
                onScanAnotherProduct: onScanAnotherProduct
            )
        }
        .navigationDestination(for: Product.self) { product in
            ProductResultView(
                product: product,
                productService: productService,
                savedStore: savedStore,
                preferences: preferences,
                onScanAnotherProduct: onScanAnotherProduct
            )
        }
    }

    private func accessibilityLabel(for product: Product) -> String {
        if !product.isLimitedData, let score = product.score {
            return "\(product.name), \(product.brand), \(product.verdict), score \(score)"
        }

        return "\(product.name), \(product.brand), Limited data"
    }

    private func summaryReason(for product: Product) -> String {
        if product.isLimitedData {
            return "Limited data"
        }

        if (product.sugarForScoring ?? .greatestFiniteMagnitude) <= 5 {
            return product.sugarLabel == "added sugar" ? "Low added sugar" : "Low sugar"
        }

        if (product.nutrition.salt100g ?? .greatestFiniteMagnitude) <= 0.8 {
            return "Lower salt"
        }

        if (product.nutrition.proteins100g ?? 0) >= 8 {
            return "Good protein"
        }

        if !product.ingredients.isEmpty && product.ingredients.count <= 4 {
            return "Short ingredients"
        }

        return product.positives.first ?? product.verdict
    }
}

private struct SavedEmptyStateCard: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            PicklyIconImage(
                systemName: systemImage,
                size: 34,
                scalesWithDynamicType: false
            )
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
    .environmentObject(SubscriptionStore(loadProducts: false))
}
