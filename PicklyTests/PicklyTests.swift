import XCTest
@testable import Pickly

@MainActor
final class PicklyTests: XCTestCase {
    func testBarcodeValidatorAcceptsValidGTINAndRejectsInvalidCheckDigit() {
        XCTAssertEqual(BarcodeValidator.normalize(" 3017620422003 "), "3017620422003")
        XCTAssertNil(BarcodeValidator.normalize("3017620422004"))
        XCTAssertNil(BarcodeValidator.normalize("123456789013"))
    }

    func testScoringUsesAddedSugarWhenAvailable() {
        let nutrition = Product.Nutrition(
            sugars100g: 18,
            addedSugars100g: 13,
            salt100g: 0.4,
            saturatedFat100g: 1.2,
            proteins100g: 6,
            fiber100g: 3
        )

        let result = ScoringService().evaluate(
            nutrition: nutrition,
            ingredients: ["Oats", "Sugar"],
            additivesTags: []
        )

        XCTAssertTrue(result.warnings.contains { $0.contains("added sugar") })
        XCTAssertFalse(result.warnings.contains { $0.contains("similar") })
        XCTAssertFalse(result.reasons.contains { $0.contains("total sugar") })
    }

    func testScoringExplainsTotalSugarFallback() {
        let nutrition = Product.Nutrition(
            sugars100g: 4,
            salt100g: 0.2,
            saturatedFat100g: 0.5,
            proteins100g: 5,
            fiber100g: 3
        )

        let result = ScoringService().evaluate(
            nutrition: nutrition,
            ingredients: ["Oats", "Water"],
            additivesTags: []
        )

        XCTAssertTrue(result.reasons.contains { $0.contains("Added sugar data is not available") })
        XCTAssertTrue(result.nutritionSummary.contains("sugar"))
    }

    func testDietaryGoalsRequireConfirmedAttributes() {
        let service = MockProductService()
        let veganProduct = service.products.first { $0.id == "simple-oat-cereal" }!
        let dairyProduct = service.products.first { $0.id == "greek-yogurt" }!
        let unknownDietaryProduct = service.products.first { $0.id == "protein-granola" }!

        XCTAssertTrue(GroceryGoal.vegan.matches(veganProduct))
        XCTAssertFalse(GroceryGoal.vegan.matches(dairyProduct))
        XCTAssertFalse(GroceryGoal.vegan.matches(unknownDietaryProduct))
    }

    func testSavedProductsPersistSnapshotsAndLists() {
        let suiteName = "PicklyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let product = MockProductService().products[1]

        let firstStore = SavedProductsStore(defaults: defaults)
        firstStore.recordView(product)
        firstStore.toggle(product)

        let secondStore = SavedProductsStore(defaults: defaults)
        XCTAssertEqual(secondStore.savedProducts.first?.productId, product.id)
        XCTAssertEqual(secondStore.recentProducts.first?.productId, product.id)
        XCTAssertEqual(secondStore.product(id: product.id), product)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testProductCodableKeepsNewMetadataAndSupportsRoundTrip() throws {
        let product = MockProductService().products[0]
        let data = try JSONEncoder().encode(product)
        let decoded = try JSONDecoder().decode(Product.self, from: data)

        XCTAssertEqual(decoded, product)
        XCTAssertEqual(decoded.source, .mock)
        XCTAssertEqual(decoded.dietary.vegetarian, .confirmed)
    }

    func testCatalogSearchAndAlternativesUseTheInjectedCatalog() {
        let catalog = ProductCatalogStore.preview
        let searchResults = catalog.searchProducts(matching: "oat")
        let cereal = catalog.product(id: "honey-crunch-cereal")!

        XCTAssertEqual(searchResults.map(\.id), ["simple-oat-cereal"])
        XCTAssertEqual(
            catalog.alternatives(for: cereal).map(\.id),
            ["simple-oat-cereal", "protein-granola"]
        )
    }
}
