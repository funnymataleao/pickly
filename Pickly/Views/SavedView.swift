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
            productService.product(id: savedProduct.productId) ?? savedStore.product(id: savedProduct.productId)
        }
    }

    private var recentProducts: [Product] {
        savedStore.recentProducts.compactMap { recentProduct in
            productService.product(id: recentProduct.productId) ?? savedStore.product(id: recentProduct.productId)
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
            LazyVStack(spacing: PicklyLayout.screenHorizontalPadding) {
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
                    ProductSummaryList(
                        products: visibleProducts,
                        reasonProvider: summaryReason(for:),
                        isSaved: savedStore.isSaved(_:),
                        onToggleSave: savedStore.toggle(_:),
                        accessibilityLabel: accessibilityLabel(for:),
                        onSelect: { product in
                            selectedProduct = product
                        }
                    )
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
    }

    private func accessibilityLabel(for product: Product) -> String {
        if !product.isLimitedData, let score = product.score {
            return "\(product.name), \(product.brand), \(product.localizedVerdict), \(PicklyCopy.localized("score")) \(score)"
        }

        return PicklyCopy.format("%@, %@, %@", product.name, product.brand, PicklyCopy.localized("Limited data"))
    }

    private func summaryReason(for product: Product) -> String {
        if product.isLimitedData {
            return PicklyCopy.localized("Limited data")
        }

        if let score = product.score, score < 70 {
            return product.warnings.first ?? PicklyCopy.localized("Review what to watch")
        }

        if (product.sugarForScoring ?? .greatestFiniteMagnitude) <= 5 {
            return PicklyCopy.localized(product.sugarLabel == "added sugar" ? "Low added sugar" : "Low sugar")
        }

        if (product.nutrition.salt100g ?? .greatestFiniteMagnitude) <= 0.8 {
            return PicklyCopy.localized("Low salt")
        }

        if (product.nutrition.proteins100g ?? 0) >= 8 {
            return PicklyCopy.localized("Good protein")
        }

        if !product.ingredients.isEmpty && product.ingredients.count <= 4 {
            return PicklyCopy.localized("Short ingredients")
        }

        return product.positives.first ?? product.localizedVerdict
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
            return PicklyCopy.localized("Saved")
        case .history:
            return PicklyCopy.localized("History")
        }
    }

    var emptyTitle: String {
        switch self {
        case .saved:
            return PicklyCopy.localized("No saved products")
        case .history:
            return PicklyCopy.localized("No recent products")
        }
    }

    var emptyDescription: String {
        switch self {
        case .saved:
            return PicklyCopy.localized("Save a product from the result screen to see it here.")
        case .history:
            return PicklyCopy.localized("Open a product result to build your recent list.")
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
