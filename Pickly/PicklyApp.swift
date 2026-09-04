//
//  PicklyApp.swift
//  Pickly
//
//  Created by mataleao on 27/04/2026.
//

import SwiftUI

@main
struct PicklyApp: App {
    @StateObject private var languageStore = PicklyLanguageStore()
    @StateObject private var subscriptionStore = SubscriptionStore()
    @StateObject private var authStore = AuthStore()
#if DEBUG
    @StateObject private var debugCatalog = ProductCatalogStore()
    @StateObject private var debugSavedStore = SavedProductsStore()
#endif

    var body: some Scene {
        WindowGroup {
            rootView
                // Recreate locale-bound catalog services after an in-app
                // language change, while keeping authentication and billing
                // state alive at the app level.
                .id(languageStore.selection.rawValue)
                .environment(\.locale, languageStore.locale)
                .environmentObject(languageStore)
                .environmentObject(subscriptionStore)
                .onOpenURL { url in
                    GoogleSignInProvider.handle(url: url)
                }
                .task {
                    await subscriptionStore.start()
                }
        }
    }

    @ViewBuilder
    private var rootView: some View {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-pickly-badge-preview") {
            ZStack {
                PicklyColor.background.ignoresSafeArea()
                ProductSliderCard(
                    product: .debugScore32,
                    reason: "Higher Pickly score",
                    reasonIcon: "arrow.left.arrow.right",
                    isSaved: false
                )
                .frame(width: 320)
                .padding()
            }
        } else if ProcessInfo.processInfo.arguments.contains("-pickly-choices-preview") {
            NavigationStack {
                SimilarProductsView(
                    product: debugComparisonProduct,
                    selection: debugComparisonSelection,
                    productService: debugCatalog,
                    savedStore: debugSavedStore,
                    preferences: .prototype,
                    onScanAnotherProduct: nil
                )
            }
        } else if ProcessInfo.processInfo.arguments.contains("-pickly-result-preview") {
            NavigationStack {
                if ProcessInfo.processInfo.arguments.contains("-pickly-empty-alternatives") {
                    ProductResultView(
                        product: debugPreviewProduct,
                        productService: MockProductService(),
                        savedStore: debugSavedStore,
                        preferences: .prototype
                    )
                } else {
                    ProductResultView(
                        product: debugPreviewProduct,
                        productService: debugCatalog,
                        savedStore: debugSavedStore,
                        preferences: .prototype
                    )
                }
            }
        } else {
            ContentView(authStore: authStore)
        }
#else
        ContentView(authStore: authStore)
#endif
    }

#if DEBUG
    private var debugPreviewProduct: Product {
        let arguments = ProcessInfo.processInfo.arguments

        if arguments.contains("-pickly-preview-almonds") {
            return .debugAlmonds
        }
        if arguments.contains("-pickly-preview-crackers") {
            return .debugSaltedCrackers
        }
        if arguments.contains("-pickly-preview-tuna") {
            return .debugTuna
        }
        if arguments.contains("-pickly-preview-flour") {
            return .debugFlour
        }
        if arguments.contains("-pickly-preview-score32") {
            return .debugScore32
        }
        if arguments.contains("-pickly-preview-ketchup") {
            return .debugKetchup
        }
        return .debugIcedTea
    }

    private var debugComparisonProduct: Product {
        MockProductService().products.first { $0.name == "Honey Crunch Cereal" } ?? .debugScore32
    }

    private var debugComparisonSelection: AlternativeShelfSelection {
        let products = MockProductService().products
        return AlternativePreviewBuilder.selection(
            for: debugComparisonProduct,
            alternatives: [],
            catalog: products
        )
    }
#endif
}

#if DEBUG
private extension Product {
    static let debugKetchup = Product(
        id: "off-8715700112596",
        barcode: "8715700112596",
        name: "Tomato Ketchup 70%",
        brand: "Heinz",
        category: "Ketchup",
        categoryTags: [
            "en:condiments", "en:sauces", "en:tomato-sauces",
            "en:ketchup", "en:tomato-ketchup"
        ],
        imageName: "takeoutbag.and.cup.and.straw.fill",
        imageURL: URL(string: "https://images.openfoodfacts.org/images/products/871/570/011/2596/front_fr.67.400.jpg"),
        ingredients: [
            "Tomatoes", "Spirit vinegar", "Sweetener", "Salt", "Spices",
            "Herbs", "Natural flavoring", "Tomato concentrate", "Water", "Citric acid"
        ],
        declaredIngredientCount: 10,
        nutrition: Nutrition(
            sugars100g: 4.4,
            salt100g: 0.05,
            saturatedFat100g: 0,
            proteins100g: 1.6,
            fiber100g: nil
        ),
        nutritionSummary: "4.4g sugar, 0.05g salt, 0g saturated fat",
        score: 81,
        summary: "A balanced option with a few details worth checking.",
        reasons: ["Low sugar per 100g", "Low salt per 100g", "Low saturated fat per 100g"],
        warnings: ["Longer ingredient list than simpler options"],
        positives: ["Low sugar", "Low salt", "Low saturated fat"],
        forYouNotes: [],
        alternativeIDs: [],
        confidence: "High",
        source: .openFoodFacts
    )

    static let debugAlmonds = Product(
        id: "off-20724696",
        barcode: "20724696",
        name: "Almonds natural",
        brand: "Alesto",
        category: "Almonds",
        imageName: "takeoutbag.and.cup.and.straw.fill",
        imageURL: URL(string: "https://images.openfoodfacts.org/images/products/000/002/072/4696/front_en.384.400.jpg"),
        ingredients: ["Almonds"],
        nutrition: Nutrition(
            sugars100g: 4.8,
            addedSugars100g: 0,
            salt100g: 0.01,
            saturatedFat100g: 4.3,
            proteins100g: 24.5,
            fiber100g: 12.1
        ),
        nutritionSummary: "0g added sugar, 0.01g salt, 4.3g saturated fat",
        score: 91,
        summary: "A strong option based on the available nutrition and ingredient data.",
        reasons: ["Low added sugar per 100g", "Simple ingredient list", "Useful protein per 100g"],
        warnings: [],
        positives: ["Simple ingredient list", "Useful protein", "Useful fiber"],
        forYouNotes: [],
        alternativeIDs: [],
        confidence: "High",
        source: .openFoodFacts
    )

    static let debugTuna = Product(
        id: "debug-tuna",
        barcode: "",
        name: "Atum em posta em óleo vegetal",
        brand: "Bom Petisco",
        category: "Conservas de peixe",
        imageName: "takeoutbag.and.cup.and.straw.fill",
        imageURL: nil,
        ingredients: ["Tuna", "Vegetable oil", "Salt"],
        nutrition: Nutrition(
            sugars100g: 0,
            salt100g: 1,
            saturatedFat100g: 1.3,
            proteins100g: 24.4,
            fiber100g: 0
        ),
        nutritionSummary: "0g sugar, 1g salt, 1.3g saturated fat",
        score: 75,
        summary: "A balanced option with a few details worth checking.",
        reasons: ["Low sugar per 100g", "Simple ingredient list", "Useful protein per 100g"],
        warnings: ["Salt is higher than ideal for everyday use"],
        positives: ["Simple ingredient list", "Useful protein"],
        forYouNotes: [],
        alternativeIDs: [],
        confidence: "High",
        source: .mock
    )

    static let debugIcedTea = Product(
        id: "debug-iced-tea",
        barcode: "3168930176435",
        name: "Ice tea",
        brand: "Lipton",
        category: "Grocery",
        imageName: "takeoutbag.and.cup.and.straw.fill",
        imageURL: URL(string: "https://images.openfoodfacts.org/images/products/316/893/017/6435/front_fr.8.400.jpg"),
        ingredients: [],
        nutrition: Nutrition(
            sugars100g: 3,
            addedSugars100g: 3,
            salt100g: 0,
            saturatedFat100g: 0,
            proteins100g: 0,
            fiber100g: 0
        ),
        nutritionSummary: "3g sugar, 0g salt, 0g saturated fat",
        score: 83,
        summary: "A balanced option with a few details worth checking.",
        reasons: ["Low sugar per 100g", "Low salt per 100g", "Low saturated fat per 100g"],
        warnings: ["Ingredient data is not available yet"],
        positives: ["Low sugar", "Low salt", "Low saturated fat"],
        forYouNotes: [],
        alternativeIDs: [],
        confidence: "Medium",
        source: .openFoodFacts
    )

    static let debugSaltedCrackers = Product(
        id: "debug-salted-crackers",
        barcode: "5601001000011",
        name: "Crackers com sal",
        brand: "Continente",
        category: "Wafers",
        imageName: "takeoutbag.and.cup.and.straw.fill",
        ingredients: ["Wheat flour", "Sunflower oil", "Salt"],
        nutrition: Nutrition(
            sugars100g: 2.2,
            salt100g: 1.4,
            saturatedFat100g: 3.1,
            proteins100g: 9.4,
            fiber100g: 3.2
        ),
        nutritionSummary: "2.2g sugar, 1.4g salt, 3.1g saturated fat",
        score: 57,
        summary: "An okay option, though some nutrition details may make it better as an occasional choice.",
        reasons: ["Moderate sugar per 100g", "Useful protein per 100g"],
        warnings: ["High sodium level per 100g"],
        positives: ["Useful protein"],
        forYouNotes: [],
        alternativeIDs: [],
        confidence: "High",
        source: .openFoodFacts
    )

    static let debugFlour = Product(
        id: "debug-flour",
        barcode: "5601001000028",
        name: "Farinha de trigo",
        brand: "Continente",
        category: "Flours",
        imageName: "takeoutbag.and.cup.and.straw.fill",
        ingredients: ["Wheat flour"],
        nutrition: Nutrition(
            sugars100g: 1.2,
            salt100g: 0.01,
            saturatedFat100g: 0.3,
            proteins100g: 10.2,
            fiber100g: 3.1
        ),
        nutritionSummary: "1.2g sugar, 0.01g salt, 0.3g saturated fat",
        score: 78,
        summary: "A solid pantry staple with a simple ingredient list.",
        reasons: ["Low sugar per 100g", "Low salt per 100g"],
        warnings: [],
        positives: ["Simple ingredient list", "Useful protein"],
        forYouNotes: [],
        alternativeIDs: [],
        confidence: "High",
        source: .openFoodFacts
    )

    static let debugScore32 = Product(
        id: "debug-score-32",
        barcode: "5601001000035",
        name: "Biscuit with a dark chocolate bar covering",
        brand: "Preview Brand",
        category: "Biscuits",
        imageName: "takeoutbag.and.cup.and.straw.fill",
        ingredients: ["Wheat flour", "Sugar", "Cocoa butter"],
        nutrition: Nutrition(
            energyKcal100g: 486,
            energyKJ100g: 2_034,
            fat100g: 23,
            carbohydrates100g: 62,
            sugars100g: 34,
            salt100g: 0.8,
            sodium100g: 0.32,
            saturatedFat100g: 14,
            proteins100g: 5,
            fiber100g: 2
        ),
        nutritionSummary: "34g sugar, 0.8g salt, 14g saturated fat",
        score: 32,
        summary: "Better as an occasional option based on the available nutrition details.",
        reasons: ["Some protein per 100g"],
        warnings: ["High sugar level per 100g", "High saturated fat level per 100g"],
        positives: [],
        forYouNotes: ["May not be the best choice if you're reducing sugar"],
        alternativeIDs: [],
        confidence: "Medium",
        source: .mock,
        facts: Facts(
            quantity: "180 g",
            servingSize: "30 g",
            nutritionBasis: .per100g,
            allergens: ["en:milk", "en:wheat"],
            traces: ["en:nuts"],
            additives: ["en:e322", "en:e500"],
            source: .mock
        )
    )
}
#endif
