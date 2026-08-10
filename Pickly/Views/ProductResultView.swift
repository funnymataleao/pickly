import SwiftUI

struct ProductResultView: View {
    let product: Product
    let productService: any ProductService
    @ObservedObject var savedStore: SavedProductsStore
    let preferences: UserPreferences
    var onScanAnotherProduct: (() -> Void)?

    init(
        product: Product,
        productService: any ProductService,
        savedStore: SavedProductsStore,
        preferences: UserPreferences,
        onScanAnotherProduct: (() -> Void)? = nil
    ) {
        self.product = product
        self.productService = productService
        self.savedStore = savedStore
        self.preferences = preferences
        self.onScanAnotherProduct = onScanAnotherProduct
    }

    var body: some View {
        ResultScreen(
            product: product,
            productService: productService,
            savedStore: savedStore,
            preferences: preferences,
            onScanAnotherProduct: onScanAnotherProduct
        )
    }
}

#Preview("Scored result") {
    NavigationStack {
        ProductResultView(
            product: MockProductService().products[1],
            productService: MockProductService(),
            savedStore: SavedProductsStore(),
            preferences: .prototype
        )
    }
    .environmentObject(SubscriptionStore(loadProducts: false))
}

#Preview("Limited data") {
    NavigationStack {
        ProductResultView(
            product: Product(
                id: "limited",
                barcode: "1234567890123",
                name: "Unknown product",
                brand: "Unknown brand",
                category: "Grocery",
                imageName: "barcode.viewfinder",
                imageURL: nil,
                ingredients: [],
                nutrition: .empty,
                nutritionSummary: "Nutrition data incomplete",
                score: nil,
                summary: "Some product details are missing.",
                reasons: ["Not enough nutrition data for a reliable score."],
                warnings: ["Ingredients not available yet.", "Nutrition facts are incomplete."],
                positives: [],
                forYouNotes: [],
                alternativeIDs: [],
                confidence: "Low"
            ),
            productService: MockProductService(),
            savedStore: SavedProductsStore(),
            preferences: .prototype
        )
    }
    .environmentObject(SubscriptionStore(loadProducts: false))
}
