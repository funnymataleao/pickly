import AuthenticationServices
import CryptoKit
import Security
import XCTest
@testable import Pickly

@MainActor
final class PicklyTests: XCTestCase {
    func testUnsupportedDeviceLanguageFallsBackToEnglish() {
        XCTAssertEqual(
            PicklyLanguage.resolve(
                preferredLocalizations: ["ru"],
                locale: Locale(identifier: "ru-RU")
            ),
            .en
        )
        XCTAssertEqual(
            PicklyLanguage.resolve(
                preferredLocalizations: ["ru", "fr"],
                locale: Locale(identifier: "ru-RU")
            ),
            .fr
        )
        XCTAssertEqual(
            PicklyLanguage.resolve(
                preferredLocalizations: [],
                locale: Locale(identifier: "pt-BR")
            ),
            .ptPT
        )
    }

    func testInAppLanguageSelectionPersistsAndResolvesSeparatelyFromDeviceLanguage() {
        let suiteName = "pickly-language-selection-test"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = PicklyLanguageStore(defaults: defaults)
        XCTAssertEqual(store.selection, .system)

        store.selection = .pl

        XCTAssertEqual(store.language, .pl)
        XCTAssertEqual(store.locale.identifier, "pl")
        XCTAssertEqual(defaults.string(forKey: PicklyLanguageSelection.storageKey), "pl")

        store.resetToSystem()
        XCTAssertEqual(store.selection, .system)
        XCTAssertEqual(defaults.string(forKey: PicklyLanguageSelection.storageKey), "system")
    }

    func testPortugueseAliasKeepsOpenFoodFactsLanguageAndMarket() {
        let context = PicklyLocaleContext(language: .ptPT, regionCode: "BR")

        XCTAssertEqual(context.openFoodFactsLanguageCode, "pt")
        XCTAssertEqual(context.preferredCountryTags.first, "en:brazil")
    }

    func testAPIConfigurationAcceptsOnlyHTTPSHostURLs() {
        XCTAssertNotNil(PicklyAPIConfiguration.validatedBaseURL(from: "https://api.example.com"))
        XCTAssertNil(PicklyAPIConfiguration.validatedBaseURL(from: "https:"))
        XCTAssertNil(PicklyAPIConfiguration.validatedBaseURL(from: "http://api.example.com"))
        XCTAssertNil(PicklyAPIConfiguration.validatedBaseURL(from: "https://"))
        XCTAssertNil(PicklyAPIConfiguration.validatedBaseURL(from: "https://user:pass@api.example.com"))
        XCTAssertNil(PicklyAPIConfiguration.validatedBaseURL(from: "https://api.example.com?token=secret"))
    }

    func testDisplayCategoryRemovesLocalizedPrefixAndUsesKnownFamilyName() {
        let product = makeCatalogProduct(
            id: "cooking-chocolate",
            name: "Chocolate para culinária",
            category: "pt:Chocolate De Culinária",
            score: 49
        )

        XCTAssertEqual(product.displayCategoryName, "Cooking chocolate")

        let fallback = makeCatalogProduct(
            id: "grocery-item",
            name: "Pantry item",
            category: "pt:ready-to-eat",
            score: 70
        )
        XCTAssertEqual(fallback.displayCategoryName, "Ready To Eat")
    }

    func testProductCardCopyKeepsCompactReasons() {
        XCTAssertEqual(
            ProductCardCopy.shortReason("Ingredient list has more than 20 items"),
            "Long list"
        )
        XCTAssertEqual(
            ProductCardCopy.shortReason("Calories are higher than similar products"),
            "Heavier pick"
        )
        XCTAssertEqual(
            ProductCardCopy.shortReason("This appears more than 20 times in the data"),
            "Worth checking"
        )
        XCTAssertEqual(
            ProductCardCopy.shortReason("Contains more added sugar than ideal for everyday use"),
            "Higher sugar"
        )
    }

    func testProductCardReasonToneUsesTheFactNotTheOverallScore() {
        XCTAssertEqual(ProductCardCopy.reasonTone("Low salt"), .positive)
        XCTAssertEqual(
            ProductCardCopy.reasonTone("Contains more added sugar than ideal for everyday use"),
            .attention
        )
        XCTAssertEqual(ProductCardCopy.reasonTone("Limited data"), .neutral)
    }

    func testGoalCardLabelsStayAlignedAcrossSurfaces() {
        XCTAssertEqual(GroceryGoal.lowSugar.productReason, "Low sugar")
        XCTAssertEqual(GroceryGoal.lowSodium.productReason, "Low sodium")
        XCTAssertEqual(GroceryGoal.highProtein.productReason, "High protein")
        XCTAssertEqual(GroceryGoal.sensitiveDigestion.productReason, "Gentler picks")

        XCTAssertEqual(ProductCardCopy.shortReason("Low salt"), "Low sodium")
        XCTAssertEqual(ProductCardCopy.shortReason("Vegetarian"), "Vegetarian")
        XCTAssertEqual(ProductCardCopy.shortReason("Vegan"), "Vegan")
        XCTAssertEqual(ProductCardCopy.shortReason("Gluten-free"), "Gluten-free")
        XCTAssertEqual(ProductCardCopy.shortReason("Lactose-free"), "Lactose-free")

        for label in ["Low sodium", "Vegetarian", "Vegan", "Gluten-free", "Lactose-free"] {
            XCTAssertEqual(ProductCardCopy.reasonTone(label), .positive, label)
        }

        let goalLabels = [
            GroceryGoal.lowSugar,
            .lowSodium,
            .highProtein,
            .shortIngredients,
            .sensitiveDigestion,
            .vegetarian,
            .vegan,
            .glutenFree,
            .lactoseFree
        ]
        let goalIcons = goalLabels.map { ProductCardCopy.icon(for: $0.title) }
        XCTAssertEqual(Set(goalIcons).count, goalIcons.count)
        XCTAssertEqual(ProductCardCopy.icon(for: "Low sugar"), GroceryGoal.lowSugar.systemImage)
        XCTAssertEqual(ProductCardCopy.icon(for: "Low sodium"), GroceryGoal.lowSodium.systemImage)
        XCTAssertEqual(ProductCardCopy.icon(for: "Vegan"), GroceryGoal.vegan.systemImage)
    }

    func testAllGoalTagUsesStrongestSelectedProductFact() {
        let preferences = UserPreferences(
            sensitiveDigestion: false,
            lowSugar: true,
            lowSodium: true,
            vegetarian: false,
            vegan: false,
            glutenFree: false,
            lactoseFree: false
        )
        let preferredGoals = GroceryGoal.preferred(in: preferences)

        let sugarLeader = makeGoalFixtureProduct(
            id: "sugar-tag-leader",
            sugars100g: 0.2,
            salt100g: 0.7
        )
        let sodiumLeader = makeGoalFixtureProduct(
            id: "sodium-tag-leader",
            sugars100g: 4.5,
            salt100g: 0.05
        )

        XCTAssertEqual(
            GroceryGoal.primaryMatch(
                for: sugarLeader,
                filter: .all,
                preferredGoals: preferredGoals
            ),
            .lowSugar
        )
        XCTAssertEqual(
            GroceryGoal.primaryMatch(
                for: sodiumLeader,
                filter: .all,
                preferredGoals: preferredGoals
            ),
            .lowSodium
        )
    }

    func testBarcodeValidatorAcceptsValidGTINAndRejectsInvalidCheckDigit() {
        XCTAssertEqual(BarcodeValidator.normalize(" 3017620422003 "), "3017620422003")
        XCTAssertEqual(BarcodeValidator.normalize("10012345678902"), "10012345678902")
        XCTAssertNil(BarcodeValidator.normalize("3017620422004"))
        XCTAssertNil(BarcodeValidator.normalize("123456789013"))
    }

    func testOpenFoodFactsSearchURLUsesTextSearchEndpoint() throws {
        let url = try XCTUnwrap(
            OpenFoodFactsService.searchURL(query: "dry pasta", pageSize: 30)
        )
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) }
        )

        XCTAssertEqual(components.path, "/cgi/search.pl")
        XCTAssertEqual(query["search_terms"], "dry pasta")
        XCTAssertEqual(query["search_simple"], "1")
        XCTAssertEqual(query["action"], "process")
        XCTAssertEqual(query["json"], "1")
        XCTAssertEqual(query["page_size"], "30")
        XCTAssertEqual(query["lc"], "en")
    }

    func testDietaryGoalUsesCanonicalOpenFoodFactsLabelSearch() throws {
        XCTAssertEqual(GroceryGoal.lactoseFree.catalogLabelTag, "en:no-lactose")

        let url = try XCTUnwrap(
            OpenFoodFactsService.labelSearchURL(label: "en:no-lactose", pageSize: 30)
        )
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) }
        )

        XCTAssertEqual(components.host, "world.openfoodfacts.org")
        XCTAssertEqual(components.path, "/api/v2/search")
        XCTAssertEqual(query["product_type"], "food")
        XCTAssertEqual(query["labels_tags"], "en:no-lactose")
        XCTAssertEqual(query["page_size"], "30")
        XCTAssertEqual(query["page"], "1")
        XCTAssertEqual(query["sort_by"], "unique_scans_n")
        XCTAssertEqual(query["lc"], "en")
    }

    func testOpenFoodFactsURLUsesResolvedPortugueseLocaleAndRegion() throws {
        let context = PicklyLocaleContext(language: .ptPT, regionCode: "BR")
        let service = OpenFoodFactsService(
            session: makeOpenFoodFactsSession(),
            localeContext: context
        )

        let url = try XCTUnwrap(
            OpenFoodFactsService.searchURL(
                query: "aveia",
                pageSize: 24,
                languageCode: context.openFoodFactsLanguageCode
            )
        )
        let query = Dictionary(
            uniqueKeysWithValues: (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [])
                .compactMap { item in item.value.map { (item.name, $0) } }
        )

        XCTAssertEqual(query["lc"], "pt")
        XCTAssertEqual(context.preferredCountryTags.first, "en:brazil")
        _ = service
    }

    func testLocalizedPresentationKeepsScoreWhileTranslatingAnalysis() {
        let product = makeGoalFixtureProduct(
            id: "localized-score",
            score: 91,
            source: .openFoodFacts
        )
        let localized = product.localizedPresentation(
            localeContext: PicklyLocaleContext(language: .fr, regionCode: "FR")
        )

        XCTAssertEqual(localized.score, product.score)
        XCTAssertFalse(localized.summary.isEmpty)
        XCTAssertEqual(localized.reasons.count, product.reasons.count)
    }

    func testGoalSearchUsesCanonicalNutrientAndDietaryTaxonomyFilters() async throws {
        OpenFoodFactsURLProtocol.reset()
        defer { OpenFoodFactsURLProtocol.reset() }

        let emptyPage = try makeOpenFoodFactsPage(
            products: [],
            count: 0,
            page: 2,
            pageSize: 30
        )
        OpenFoodFactsURLProtocol.requestHandler = { _ in
            .init(statusCode: 200, data: emptyPage)
        }

        let service = OpenFoodFactsService(session: makeOpenFoodFactsSession())
        _ = try await service.searchProductPage(for: .lowSugar, pageSize: 30, page: 2)
        _ = try await service.searchProductPage(for: .lowSodium, pageSize: 30, page: 2)
        _ = try await service.searchProductPage(for: .vegetarian, pageSize: 30, page: 2)

        let requests = OpenFoodFactsURLProtocol.requestedURLs.map(OpenFoodFactsRequest.init(url:))
        XCTAssertEqual(requests.count, 3)
        XCTAssertTrue(requests.allSatisfy { $0.host == "world.openfoodfacts.org" })
        XCTAssertTrue(requests.allSatisfy { $0.path == "/api/v2/search" })
        XCTAssertTrue(requests.allSatisfy { $0.query["page"] == "2" })

        XCTAssertEqual(requests[0].query["nutrient_levels_tags"], "en:sugars-in-low-quantity")
        XCTAssertNil(requests[0].query["labels_tags"])
        XCTAssertEqual(requests[1].query["nutrient_levels_tags"], "en:salt-in-low-quantity")
        XCTAssertNil(requests[1].query["labels_tags"])
        XCTAssertEqual(requests[2].query["labels_tags"], "en:vegetarian")
        XCTAssertNil(requests[2].query["nutrient_levels_tags"])
    }

    func testAlmondRelatedSearchUsesOpenFoodFactsTaxonomyAndPagination() throws {
        let almonds = makeCatalogProduct(
            id: "almonds-natural",
            name: "Almonds natural",
            category: "Almonds",
            score: 91
        )
        XCTAssertEqual(RelatedProductQuery.categoryTags(for: almonds), ["en:almonds"])

        let url = try XCTUnwrap(
            OpenFoodFactsService.categorySearchURL(
                categoryTag: "en:almonds",
                pageSize: 50,
                page: 2
            )
        )
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) }
        )

        XCTAssertEqual(components.host, "world.openfoodfacts.org")
        XCTAssertEqual(components.path, "/api/v2/search")
        XCTAssertEqual(query["product_type"], "food")
        XCTAssertEqual(query["categories_tags"], "en:almonds")
        XCTAssertEqual(query["page_size"], "50")
        XCTAssertEqual(query["page"], "2")
        XCTAssertEqual(query["sort_by"], "unique_scans_n")
    }

    func testKetchupCategoryProxyAndDirectURLsCarryTaxonomyMarketLanguageAndPage() throws {
        let directURL = try XCTUnwrap(
            OpenFoodFactsService.categorySearchURL(
                categoryTag: "en:ketchup",
                pageSize: 50,
                page: 3,
                countryTag: "en:portugal"
            )
        )
        let directRequest = OpenFoodFactsRequest(url: directURL)

        XCTAssertEqual(directRequest.host, "world.openfoodfacts.org")
        XCTAssertEqual(directRequest.path, "/api/v2/search")
        XCTAssertEqual(directRequest.query["categories_tags"], "en:ketchup")
        XCTAssertEqual(directRequest.query["countries_tags_en"], "portugal")
        XCTAssertEqual(directRequest.query["page"], "3")
        XCTAssertEqual(directRequest.query["page_size"], "50")
        XCTAssertEqual(directRequest.query["lc"], "pt")

        let proxyURL = try XCTUnwrap(
            OpenFoodFactsService.categoryProxyURL(
                baseURL: try XCTUnwrap(URL(string: "https://api.pickly.test")),
                categoryTag: "en:ketchup",
                pageSize: 50,
                page: 3,
                countryTag: "en:portugal"
            )
        )
        let proxyRequest = OpenFoodFactsRequest(url: proxyURL)

        XCTAssertEqual(proxyRequest.host, "api.pickly.test")
        XCTAssertEqual(proxyRequest.path, "/v1/categories/en:ketchup")
        XCTAssertEqual(proxyRequest.query["page"], "3")
        XCTAssertEqual(proxyRequest.query["page_size"], "50")
        XCTAssertEqual(proxyRequest.query["country"], "en:portugal")
        XCTAssertEqual(proxyRequest.query["lang"], "pt")
    }

    func testOpenFoodFactsTextSearchUsesOnlyProductionHost() async throws {
        OpenFoodFactsURLProtocol.reset()
        OpenFoodFactsURLProtocol.responseData = Data("{\"products\":[]}".utf8)
        defer { OpenFoodFactsURLProtocol.reset() }

        let service = OpenFoodFactsService(session: makeOpenFoodFactsSession())
        _ = try await service.searchProducts(matching: "almonds", pageSize: 50)

        XCTAssertEqual(OpenFoodFactsURLProtocol.requestedHosts, ["world.openfoodfacts.org"])
    }

    func testScreenshotKetchupBarcodePrefersEnglishNameAndMapsKetchupFamily() async throws {
        OpenFoodFactsURLProtocol.reset()
        defer { OpenFoodFactsURLProtocol.reset() }

        let fixture = makeOpenFoodFactsProduct(
            code: "8715700112596",
            name: "Ketchup aux tomates 70%",
            sugars100g: 22,
            salt100g: 2.2,
            englishName: "Tomato Ketchup 70%",
            brand: "Heinz",
            categories: "Condiments, Sauces, Tomato sauces, Ketchup",
            categoryTags: ["en:ketchup"]
        )
        OpenFoodFactsURLProtocol.responseData = try JSONSerialization.data(
            withJSONObject: [
                "code": "8715700112596",
                "status": "success",
                "product": fixture
            ]
        )

        let service = OpenFoodFactsService(session: makeOpenFoodFactsSession())
        let product = try await service.fetchProduct(barcode: "8715700112596")

        XCTAssertEqual(product.barcode, "8715700112596")
        XCTAssertEqual(product.name, "Tomato Ketchup 70%")
        XCTAssertEqual(product.category, "Ketchup")
        XCTAssertEqual(product.categoryTags, ["en:ketchup"])
        XCTAssertEqual(ProductFamily.classify(product), .ketchup)
        XCTAssertEqual(product.displayCategoryName, "Ketchup")
    }

    func testMislabeledFrenchEnglishNameUsesVerifiedGenericEnglishName() async throws {
        OpenFoodFactsURLProtocol.reset()
        defer { OpenFoodFactsURLProtocol.reset() }

        let fixture = makeOpenFoodFactsProduct(
            code: "20995553",
            name: "Chocolat noir - 85% cacao",
            sugars100g: 18,
            salt100g: 0.02,
            englishName: "Chocolat noir - 85% cacao",
            brand: "Fixture Chocolate",
            categories: "Chocolate",
            categoryTags: ["en:dark-chocolates"],
            language: "en",
            genericEnglishName: "Dark chocolate"
        )
        OpenFoodFactsURLProtocol.responseData = try JSONSerialization.data(
            withJSONObject: [
                "code": "20995553",
                "status": "success",
                "product": fixture
            ]
        )

        let product = try await OpenFoodFactsService(session: makeOpenFoodFactsSession())
            .fetchProduct(barcode: "20995553")

        XCTAssertEqual(product.name, "Dark chocolate")
        XCTAssertFalse(product.name.localizedCaseInsensitiveContains("Chocolat noir"))
    }

    func testMislabeledGermanEnglishNameFallsBackToEnglishBrandCategoryName() async throws {
        OpenFoodFactsURLProtocol.reset()
        defer { OpenFoodFactsURLProtocol.reset() }

        let fixture = makeOpenFoodFactsProduct(
            code: "4056489139393",
            name: "Tomatenketchup Original",
            sugars100g: 18,
            salt100g: 1.8,
            englishName: "Kania Tomatenketchup Original",
            brand: "Kania",
            categories: "Würzmittel, Saucen, Ketchup",
            categoryTags: ["en:condiments", "en:sauces", "en:ketchup"],
            language: "en"
        )
        OpenFoodFactsURLProtocol.responseData = try JSONSerialization.data(
            withJSONObject: [
                "code": "4056489139393",
                "status": "success",
                "product": fixture
            ]
        )

        let product = try await OpenFoodFactsService(session: makeOpenFoodFactsSession())
            .fetchProduct(barcode: "4056489139393")

        XCTAssertEqual(product.name, "Kania Ketchup")
        XCTAssertFalse(product.name.localizedCaseInsensitiveContains("Tomaten"))
    }

    func testEnglishProductNameResolverPreservesEnglishAndBrandLikeNames() {
        XCTAssertEqual(
            EnglishProductNameResolver.resolvedName(
                candidates: ["Tomato Ketchup 70%"],
                brand: "Heinz",
                category: "Ketchup",
                categoryTags: ["en:ketchup"]
            ),
            "Tomato Ketchup 70%"
        )
        XCTAssertEqual(
            EnglishProductNameResolver.resolvedName(
                candidates: ["Coca-Cola Zero"],
                brand: "Coca-Cola",
                category: "Soft drinks",
                categoryTags: ["en:soft-drinks"]
            ),
            "Coca-Cola Zero"
        )
        XCTAssertEqual(
            EnglishProductNameResolver.resolvedName(
                candidates: ["Oreo"],
                brand: "Mondelez",
                category: "Cookies",
                categoryTags: ["en:cookies"]
            ),
            "Oreo"
        )
        XCTAssertEqual(
            EnglishProductNameResolver.resolvedName(
                candidates: ["Buttermilk"],
                brand: "Farm Dairy",
                category: "Milk",
                categoryTags: ["en:milk"]
            ),
            "Buttermilk"
        )
        XCTAssertEqual(
            EnglishProductNameResolver.resolvedName(
                candidates: ["Milkshake"],
                brand: "Farm Dairy",
                category: "Milk drinks",
                categoryTags: ["en:milk"]
            ),
            "Milkshake"
        )
    }

    func testEnglishProductNameResolverReplacesPublishedForeignLabelsWithSafeDescriptors() {
        XCTAssertEqual(
            EnglishProductNameResolver.resolvedName(
                candidates: ["Spaghetti au quinoa, ail et persil"],
                brand: "Jardin Bio",
                category: "Dry pasta",
                categoryTags: []
            ),
            "Jardin Bio Dry pasta"
        )
        XCTAssertEqual(
            EnglishProductNameResolver.resolvedName(
                candidates: ["ديليسيوس بيرلي"],
                brand: "COPAG",
                category: "Yogurt",
                categoryTags: []
            ),
            "COPAG Yogurt"
        )
    }

    func testEnglishProductNameResolverRepairsSavedProductSnapshot() {
        let savedSnapshot = makeCatalogProduct(
            id: "saved-ketchup",
            name: "Tomatenketchup Original",
            category: "Würzmittel",
            score: 70,
            brand: "Kania",
            categoryTags: ["en:ketchup"],
            source: .openFoodFacts
        )

        XCTAssertEqual(EnglishProductNameResolver.displayName(for: savedSnapshot), "Kania Ketchup")
    }

    func testNonEnglishOpenFoodFactsNameUsesEnglishBrandCategoryDescriptor() async throws {
        OpenFoodFactsURLProtocol.reset()
        defer { OpenFoodFactsURLProtocol.reset() }

        let fixture = makeOpenFoodFactsProduct(
            code: "4056489139393",
            name: "Tomatenketchup Original",
            sugars100g: 18,
            salt100g: 1.8,
            brand: "Kania",
            categories: "Würzmittel, Saucen, Ketchup",
            categoryTags: ["en:condiments", "en:sauces", "en:ketchup"],
            language: "de"
        )
        OpenFoodFactsURLProtocol.responseData = try JSONSerialization.data(
            withJSONObject: [
                "code": "4056489139393",
                "status": "success",
                "product": fixture
            ]
        )

        let service = OpenFoodFactsService(session: makeOpenFoodFactsSession())
        let product = try await service.fetchProduct(barcode: "4056489139393")

        XCTAssertEqual(product.name, "Kania Ketchup")
        XCTAssertFalse(product.name.localizedCaseInsensitiveContains("Tomaten"))
        XCTAssertEqual(ProductFamily.classify(product), .ketchup)
    }

    func testGenericEnglishNamePrecedesNonEnglishSourceName() async throws {
        OpenFoodFactsURLProtocol.reset()
        defer { OpenFoodFactsURLProtocol.reset() }

        let fixture = makeOpenFoodFactsProduct(
            code: "5601009974405",
            name: "Ketchup à Portuguesa",
            sugars100g: 25,
            salt100g: 2.2,
            brand: "Pingo Doce",
            categories: "Molhos, Ketchup",
            categoryTags: ["en:ketchup"],
            language: "pt",
            genericEnglishName: "Tomato ketchup"
        )
        OpenFoodFactsURLProtocol.responseData = try JSONSerialization.data(
            withJSONObject: [
                "code": "5601009974405",
                "status": "success",
                "product": fixture
            ]
        )

        let service = OpenFoodFactsService(session: makeOpenFoodFactsSession())
        let product = try await service.fetchProduct(barcode: "5601009974405")

        XCTAssertEqual(product.name, "Tomato ketchup")
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

    func testScoringOmitsWatchOutsWhenThereAreNoConcreteConcerns() {
        let result = ScoringService().evaluate(
            nutrition: Product.Nutrition(
                sugars100g: 4,
                salt100g: 0.2,
                saturatedFat100g: 0.5,
                proteins100g: 5,
                fiber100g: 3
            ),
            ingredients: ["Oats", "Water"],
            additivesTags: []
        )

        XCTAssertTrue(result.warnings.isEmpty)
    }

    func testScoringTreatsSugaryBeverageAsAWatchOut() {
        let result = ScoringService().evaluate(
            nutrition: Product.Nutrition(
                sugars100g: 10.6,
                salt100g: 0,
                saturatedFat100g: 0,
                proteins100g: 0,
                fiber100g: 0
            ),
            ingredients: ["Carbonated water", "Sugar", "Colour"],
            additivesTags: [],
            category: "Soft drinks"
        )

        XCTAssertEqual(result.score, 62)
        XCTAssertTrue(result.warnings.contains { $0.contains("more sugar") })
        XCTAssertFalse(result.warnings.contains("No major watch-outs in the available data"))
    }

    func testScoringRequiresCoreNegativeNutritionFields() {
        let result = ScoringService().evaluate(
            nutrition: Product.Nutrition(proteins100g: 20, fiber100g: 10),
            ingredients: ["Oats"],
            additivesTags: [],
            category: "Breakfast"
        )

        XCTAssertNil(result.score)
        XCTAssertEqual(result.confidence, "Low")
        XCTAssertTrue(result.warnings.contains("Nutrition facts are incomplete."))
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

    func testLactoseFreeGoalDoesNotRequireANutritionScore() {
        let product = Product(
            id: "lactose-free-limited",
            barcode: "1234567890123",
            name: "Lactose-free oat drink",
            brand: "Example",
            category: "Drinks",
            imageName: "cup.and.saucer",
            imageURL: URL(string: "https://example.com/oat-drink.jpg"),
            ingredients: [],
            nutrition: .empty,
            nutritionSummary: "Nutrition data incomplete",
            score: nil,
            summary: "Dietary label confirmed.",
            reasons: [],
            warnings: [],
            positives: [],
            forYouNotes: [],
            alternativeIDs: [],
            confidence: "Low",
            dietary: DietaryAttributes(lactoseFree: .confirmed)
        )

        XCTAssertTrue(GroceryGoal.lactoseFree.matches(product))
        XCTAssertFalse(GroceryGoal.lowSugar.matches(product))
    }

    func testLactoseFreeSearchMapsNoLactoseLabel() async throws {
        OpenFoodFactsURLProtocol.reset()
        OpenFoodFactsURLProtocol.responseData = Data(
            #"""
            {
              "products": [{
                "code": "3017620422003",
                "product_name": "Lait sans lactose",
                "brands": "Example Dairy",
                "categories": "Dairy drinks",
                "categories_tags": ["en:dairy-drinks"],
                "image_front_url": "https://example.com/lactose-free.jpg",
                "ingredients": [],
                "ingredients_text": "Milk, lactase",
                "nutriments": {
                  "sugars_100g": 4,
                  "salt_100g": 0.1,
                  "saturated-fat_100g": 1,
                  "proteins_100g": 3,
                  "fiber_100g": 0
                },
                "labels_tags": ["en:no-lactose"],
                "allergens_tags": ["en:milk"],
                "traces_tags": []
              }]
            }
            """#.utf8
        )
        defer { OpenFoodFactsURLProtocol.reset() }

        let service = OpenFoodFactsService(
            session: makeOpenFoodFactsSession()
        )
        let products = try await service.searchProducts(for: .lactoseFree, pageSize: 12)
        let product = try XCTUnwrap(products.first)

        XCTAssertEqual(product.dietary.lactoseFree, .confirmed)
        XCTAssertTrue(GroceryGoal.lactoseFree.matches(product))
    }

    func testGoalResponseDecodesStringIngredientCountAndUsesItForMatching() async throws {
        OpenFoodFactsURLProtocol.reset()
        defer { OpenFoodFactsURLProtocol.reset() }
        OpenFoodFactsURLProtocol.responseData = Data(
            #"""
            {
              "count": 1,
              "page": 1,
              "page_size": 12,
              "products": [{
                "code": "3017620422003",
                "product_name": "Ten Ingredient Meal",
                "brands": "Fixture Brand",
                "categories": "Prepared meals",
                "categories_tags": ["en:prepared-meals"],
                "image_front_url": "https://example.com/ten-ingredient-meal.jpg",
                "ingredients_n": "10",
                "ingredients": [{
                  "id": "en:water",
                  "text": "Water"
                }],
                "ingredients_text": "Water",
                "nutriments": {
                  "sugars_100g": 3,
                  "salt_100g": 0.2,
                  "saturated-fat_100g": 1,
                  "proteins_100g": 4,
                  "fiber_100g": 2
                },
                "labels_tags": [],
                "allergens_tags": [],
                "traces_tags": []
              }]
            }
            """#.utf8
        )

        let service = OpenFoodFactsService(session: makeOpenFoodFactsSession())
        let page = try await service.searchProductPage(
            for: .sensitiveDigestion,
            pageSize: 12,
            page: 1
        )
        let product = try XCTUnwrap(page.products.first)

        XCTAssertEqual(product.ingredients.count, 1)
        XCTAssertEqual(product.declaredIngredientCount, 10)
        XCTAssertEqual(product.ingredientCountForMatching, 10)
        XCTAssertFalse(GroceryGoal.sensitiveDigestion.matches(product))
    }

    func testGoalRecommendationsKeepSugarSodiumAndVegetarianPoolsIndependent() async throws {
        OpenFoodFactsURLProtocol.reset()
        defer { OpenFoodFactsURLProtocol.reset() }

        let pagesByTag = [
            "en:sugars-in-low-quantity": try makeOpenFoodFactsPage(
                products: [
                    makeOpenFoodFactsProduct(
                        code: "3017620422003",
                        name: "Low Sugar Oats",
                        sugars100g: 2,
                        salt100g: 1.2
                    )
                ],
                count: 1_201,
                page: 1,
                pageSize: 50
            ),
            "en:salt-in-low-quantity": try makeOpenFoodFactsPage(
                products: [
                    makeOpenFoodFactsProduct(
                        code: "4006381333931",
                        name: "Low Sodium Soup",
                        sugars100g: 12,
                        salt100g: 0.2
                    )
                ],
                count: 2_302,
                page: 1,
                pageSize: 50
            ),
            "en:vegetarian": try makeOpenFoodFactsPage(
                products: [
                    makeOpenFoodFactsProduct(
                        code: "5901234123457",
                        name: "Vegetarian Curry",
                        sugars100g: 12,
                        salt100g: 1.2,
                        labels: ["en:vegetarian"]
                    )
                ],
                count: 129_061,
                page: 1,
                pageSize: 50
            )
        ]
        OpenFoodFactsURLProtocol.requestHandler = { request in
            let route = OpenFoodFactsRequest(request: request).taxonomyTag
            guard let data = route.flatMap({ pagesByTag[$0] }) else {
                return .init(statusCode: 404, data: Data())
            }
            return .init(statusCode: 200, data: data)
        }

        let session = makeOpenFoodFactsSession()
        let store = makeGoalCatalogStore(session: session)
        let goals: [GroceryGoal] = [.lowSugar, .lowSodium, .vegetarian]

        await store.loadGoalRecommendations(for: goals, limit: 1)

        XCTAssertEqual(
            store.goalProducts(for: .lowSugar, preferredGoals: goals).map(\.id),
            ["off-3017620422003"]
        )
        XCTAssertEqual(
            store.goalProducts(for: .lowSodium, preferredGoals: goals).map(\.id),
            ["off-4006381333931"]
        )
        XCTAssertEqual(
            store.goalProducts(for: .vegetarian, preferredGoals: goals).map(\.id),
            ["off-5901234123457"]
        )
        XCTAssertEqual(store.goalRecommendationTotal(for: .lowSugar, preferredGoals: goals), 1_201)
        XCTAssertEqual(store.goalRecommendationTotal(for: .lowSodium, preferredGoals: goals), 2_302)
        XCTAssertEqual(store.goalRecommendationTotal(for: .vegetarian, preferredGoals: goals), 129_061)

        let requestedTags = OpenFoodFactsURLProtocol.requestedURLs.compactMap {
            OpenFoodFactsRequest(url: $0).taxonomyTag
        }
        XCTAssertEqual(requestedTags, [
            "en:sugars-in-low-quantity",
            "en:salt-in-low-quantity",
            "en:vegetarian"
        ])
        XCTAssertTrue(OpenFoodFactsURLProtocol.requestedHosts.allSatisfy { $0 == "world.openfoodfacts.org" })
    }

    func testProductsAlreadyInSharedCatalogDoNotSuppressGoalSpecificRequests() async throws {
        OpenFoodFactsURLProtocol.reset()
        defer { OpenFoodFactsURLProtocol.reset() }

        let pagesByTag = [
            "en:vegetarian": try makeOpenFoodFactsPage(
                products: [
                    makeOpenFoodFactsProduct(
                        code: "3017620422003",
                        name: "Shared Healthy Product",
                        sugars100g: 2,
                        salt100g: 0.2,
                        labels: ["en:vegetarian"]
                    )
                ],
                count: 1,
                page: 1,
                pageSize: 50
            ),
            "en:sugars-in-low-quantity": try makeOpenFoodFactsPage(
                products: [
                    makeOpenFoodFactsProduct(
                        code: "4006381333931",
                        name: "Dedicated Sugar Product",
                        sugars100g: 1,
                        salt100g: 1.1
                    )
                ],
                count: 900,
                page: 1,
                pageSize: 50
            ),
            "en:salt-in-low-quantity": try makeOpenFoodFactsPage(
                products: [
                    makeOpenFoodFactsProduct(
                        code: "5901234123457",
                        name: "Dedicated Sodium Product",
                        sugars100g: 14,
                        salt100g: 0.1
                    )
                ],
                count: 800,
                page: 1,
                pageSize: 50
            )
        ]
        OpenFoodFactsURLProtocol.requestHandler = { request in
            let route = OpenFoodFactsRequest(request: request).taxonomyTag
            guard let data = route.flatMap({ pagesByTag[$0] }) else {
                return .init(statusCode: 404, data: Data())
            }
            return .init(statusCode: 200, data: data)
        }

        let store = makeGoalCatalogStore(session: makeOpenFoodFactsSession())
        await store.loadGoalRecommendations(for: [.vegetarian], limit: 1)

        let sharedProduct = try XCTUnwrap(store.product(id: "off-3017620422003"))
        XCTAssertTrue(GroceryGoal.lowSugar.matches(sharedProduct))
        XCTAssertTrue(GroceryGoal.lowSodium.matches(sharedProduct))

        await store.loadGoalRecommendations(for: [.lowSugar, .lowSodium], limit: 1)

        XCTAssertEqual(
            store.goalProducts(for: .lowSugar, preferredGoals: [.lowSugar, .lowSodium]).map(\.id),
            ["off-4006381333931"]
        )
        XCTAssertEqual(
            store.goalProducts(for: .lowSodium, preferredGoals: [.lowSugar, .lowSodium]).map(\.id),
            ["off-5901234123457"]
        )
        let requestedTags = OpenFoodFactsURLProtocol.requestedURLs.compactMap {
            OpenFoodFactsRequest(url: $0).taxonomyTag
        }
        XCTAssertEqual(requestedTags, [
            "en:vegetarian",
            "en:sugars-in-low-quantity",
            "en:salt-in-low-quantity"
        ])
    }

    func testGoalPaginationPreservesMetadataAndDeduplicatesAcrossPages() async throws {
        OpenFoodFactsURLProtocol.reset()
        defer { OpenFoodFactsURLProtocol.reset() }

        let productA = makeOpenFoodFactsProduct(
            code: "3017620422003",
            name: "Vegetarian Product A",
            sugars100g: 8,
            salt100g: 0.9,
            labels: ["en:vegetarian"]
        )
        let productB = makeOpenFoodFactsProduct(
            code: "4006381333931",
            name: "Vegetarian Product B",
            sugars100g: 9,
            salt100g: 1,
            labels: ["en:vegetarian"]
        )
        let productC = makeOpenFoodFactsProduct(
            code: "5901234123457",
            name: "Vegetarian Product C",
            sugars100g: 10,
            salt100g: 1.1,
            labels: ["en:vegetarian"]
        )
        let pages = [
            1: try makeOpenFoodFactsPage(products: [productA], count: 150, page: 1, pageSize: 50),
            2: try makeOpenFoodFactsPage(products: [productA, productB], count: 150, page: 2, pageSize: 50),
            3: try makeOpenFoodFactsPage(products: [productB, productC], count: 150, page: 3, pageSize: 50)
        ]
        OpenFoodFactsURLProtocol.requestHandler = { request in
            let parsed = OpenFoodFactsRequest(request: request)
            guard parsed.taxonomyTag == "en:vegetarian",
                  let page = parsed.page,
                  let data = pages[page] else {
                return .init(statusCode: 404, data: Data())
            }
            return .init(statusCode: 200, data: data)
        }

        let store = makeGoalCatalogStore(session: makeOpenFoodFactsSession())
        await store.loadGoalRecommendations(for: [.vegetarian], limit: 1)

        XCTAssertEqual(store.goalRecommendationTotals[.vegetarian], 150)
        XCTAssertEqual(store.goalRecommendationPages[.vegetarian], 1)
        XCTAssertTrue(store.hasMoreGoalRecommendations(for: .vegetarian))

        await store.loadMoreGoalRecommendations(for: .vegetarian, pageSize: 1)
        XCTAssertEqual(store.goalRecommendationPages[.vegetarian], 2)
        XCTAssertTrue(store.hasMoreGoalRecommendations(for: .vegetarian))

        await store.loadMoreGoalRecommendations(for: .vegetarian, pageSize: 1)

        XCTAssertEqual(
            store.goalProducts(for: .vegetarian, preferredGoals: [.vegetarian]).map(\.id),
            ["off-3017620422003", "off-4006381333931", "off-5901234123457"]
        )
        XCTAssertEqual(store.goalRecommendationProductIDs[.vegetarian]?.count, 3)
        XCTAssertEqual(store.goalRecommendationTotals[.vegetarian], 150)
        XCTAssertEqual(store.goalRecommendationPages[.vegetarian], 3)
        XCTAssertFalse(store.hasMoreGoalRecommendations(for: .vegetarian))

        let requestedPages = OpenFoodFactsURLProtocol.requestedURLs.compactMap {
            OpenFoodFactsRequest(url: $0).page
        }
        XCTAssertEqual(requestedPages, [1, 2, 3])
    }

    func testGoalFailureIsScopedAndNeverFallsBackToStaging() async throws {
        OpenFoodFactsURLProtocol.reset()
        defer { OpenFoodFactsURLProtocol.reset() }

        let lowSugarPage = try makeOpenFoodFactsPage(
            products: [
                makeOpenFoodFactsProduct(
                    code: "3017620422003",
                    name: "Low Sugar Product",
                    sugars100g: 2,
                    salt100g: 1
                )
            ],
            count: 1,
            page: 1,
            pageSize: 50
        )
        OpenFoodFactsURLProtocol.requestHandler = { request in
            switch OpenFoodFactsRequest(request: request).taxonomyTag {
            case "en:sugars-in-low-quantity":
                return .init(statusCode: 200, data: lowSugarPage)
            case "en:vegetarian":
                return .init(statusCode: 503, data: Data())
            default:
                return .init(statusCode: 404, data: Data())
            }
        }

        let store = makeGoalCatalogStore(session: makeOpenFoodFactsSession())
        let goals: [GroceryGoal] = [.lowSugar, .vegetarian]
        await store.loadGoalRecommendations(for: goals, limit: 1)

        XCTAssertEqual(
            store.goalProducts(for: .lowSugar, preferredGoals: goals).map(\.id),
            ["off-3017620422003"]
        )
        XCTAssertNil(store.goalRecommendationError(for: .lowSugar, preferredGoals: goals))
        XCTAssertTrue(store.goalProducts(for: .vegetarian, preferredGoals: goals).isEmpty)
        XCTAssertNotNil(store.goalRecommendationError(for: .vegetarian, preferredGoals: goals))
        XCTAssertFalse(OpenFoodFactsURLProtocol.requestedHosts.isEmpty)
        XCTAssertTrue(OpenFoodFactsURLProtocol.requestedHosts.allSatisfy { $0 == "world.openfoodfacts.org" })
    }

    func testGoalMatchingProductsDeduplicatesAndFiltersPreferredGoals() {
        let products = MockProductService().products
        let preferred: [GroceryGoal] = [.lowSugar, .vegan]

        let allMatches = GroceryGoal.matchingProducts(
            in: products,
            filter: .all,
            preferredGoals: preferred
        )
        let veganMatches = GroceryGoal.matchingProducts(
            in: products,
            filter: .vegan,
            preferredGoals: preferred
        )

        XCTAssertEqual(Set(allMatches.map(\.id)).count, allMatches.count)
        XCTAssertTrue(allMatches.allSatisfy { product in
            preferred.contains { $0.matches(product) }
        })
        XCTAssertTrue(veganMatches.allSatisfy { GroceryGoal.vegan.matches($0) })
        XCTAssertTrue(allMatches.map(\.id).contains("simple-oat-cereal"))
        XCTAssertFalse(veganMatches.map(\.id).contains("greek-yogurt"))
    }

    func testHealthiestGoalMatchesAreOrderedByScore() {
        let products = MockProductService().products
        let preferred: [GroceryGoal] = [.lowSugar, .vegan]

        let matches = GroceryGoal.healthiestMatchingProducts(
            in: products,
            filter: .all,
            preferredGoals: preferred
        )
        let scores = matches.compactMap(\.score)

        XCTAssertEqual(scores, scores.sorted(by: >))
        XCTAssertTrue(matches.allSatisfy { product in
            preferred.contains { $0.matches(product) }
        })
    }

    func testMergingCatalogDataPreservesCuratedScoringAlternativesAndOFFDietaryInBothOrders() {
        let curated = makeGoalFixtureProduct(
            id: "catalog-product",
            barcode: "3017620422003",
            score: 94,
            summary: "Curated catalog summary",
            alternativeIDs: ["curated-alternative"],
            source: .unknown
        )
        let openFoodFacts = makeGoalFixtureProduct(
            id: "off-3017620422003",
            barcode: "3017620422003",
            score: 42,
            summary: "Open Food Facts summary",
            alternativeIDs: ["off-alternative"],
            dietary: DietaryAttributes(
                vegetarian: .confirmed,
                vegan: .confirmed,
                glutenFree: .unknown,
                lactoseFree: .unknown
            ),
            source: .openFoodFacts
        )

        let curatedThenOFF = curated.mergingCatalogData(from: openFoodFacts)
        let offThenCurated = openFoodFacts.mergingCatalogData(from: curated)

        for merged in [curatedThenOFF, offThenCurated] {
            XCTAssertEqual(merged.score, 94)
            XCTAssertEqual(merged.summary, "Curated catalog summary")
            XCTAssertEqual(Set(merged.alternativeIDs), ["curated-alternative", "off-alternative"])
            XCTAssertEqual(merged.dietary.vegetarian, .confirmed)
            XCTAssertEqual(merged.dietary.vegan, .confirmed)
        }
    }

    func testSensitiveDigestionUsesDeclaredIngredientCountInsteadOfParsedArrayLength() {
        let parsedOnly = makeGoalFixtureProduct(
            id: "parsed-only",
            ingredients: ["Water"],
            declaredIngredientCount: nil
        )
        let declaredFour = makeGoalFixtureProduct(
            id: "declared-four",
            ingredients: ["Water"],
            declaredIngredientCount: 4
        )
        let declaredFive = makeGoalFixtureProduct(
            id: "declared-five",
            ingredients: ["Water"],
            declaredIngredientCount: 5
        )

        XCTAssertTrue(GroceryGoal.sensitiveDigestion.matches(parsedOnly))
        XCTAssertTrue(GroceryGoal.sensitiveDigestion.matches(declaredFour))
        XCTAssertFalse(GroceryGoal.sensitiveDigestion.matches(declaredFive))
        XCTAssertEqual(declaredFive.ingredientCountForMatching, 5)
    }

    func testMergingCatalogDataGivesNegativeDietaryStatusPriorityInBothOrders() {
        let confirmed = makeGoalFixtureProduct(
            id: "confirmed-product",
            barcode: "4006381333931",
            dietary: DietaryAttributes(
                vegetarian: .confirmed,
                vegan: .confirmed,
                glutenFree: .confirmed,
                lactoseFree: .confirmed
            )
        )
        let rejected = makeGoalFixtureProduct(
            id: "rejected-product",
            barcode: "4006381333931",
            dietary: DietaryAttributes(
                vegetarian: .notSuitable,
                vegan: .notSuitable,
                glutenFree: .notSuitable,
                lactoseFree: .notSuitable
            ),
            source: .openFoodFacts
        )

        for merged in [
            confirmed.mergingCatalogData(from: rejected),
            rejected.mergingCatalogData(from: confirmed)
        ] {
            XCTAssertEqual(merged.dietary.vegetarian, .notSuitable)
            XCTAssertEqual(merged.dietary.vegan, .notSuitable)
            XCTAssertEqual(merged.dietary.glutenFree, .notSuitable)
            XCTAssertEqual(merged.dietary.lactoseFree, .notSuitable)
        }
    }

    func testRankedFeedProductsUseGoalStrengthToSeparateLowSugarAndLowSodiumLeaders() {
        let sugarLeader = makeGoalFixtureProduct(
            id: "sugar-leader",
            category: "Breakfast",
            sugars100g: 0.2,
            salt100g: 0.7,
            score: 82
        )
        let sodiumLeader = makeGoalFixtureProduct(
            id: "sodium-leader",
            category: "Soup",
            sugars100g: 4.8,
            salt100g: 0.05,
            score: 96
        )
        let overlappingProducts = [sodiumLeader, sugarLeader]

        XCTAssertTrue(overlappingProducts.allSatisfy { GroceryGoal.lowSugar.matches($0) })
        XCTAssertTrue(overlappingProducts.allSatisfy { GroceryGoal.lowSodium.matches($0) })

        let lowSugarFeed = GroceryGoal.rankedFeedProducts(
            in: overlappingProducts,
            for: .lowSugar
        )
        let lowSodiumFeed = GroceryGoal.rankedFeedProducts(
            in: overlappingProducts,
            for: .lowSodium
        )

        XCTAssertEqual(lowSugarFeed.first?.id, "sugar-leader")
        XCTAssertEqual(lowSodiumFeed.first?.id, "sodium-leader")
        XCTAssertNotEqual(lowSugarFeed.first?.id, lowSodiumFeed.first?.id)
    }

    func testSensitiveDigestionGoalUsesGentlerPicksTitle() {
        XCTAssertEqual(GroceryGoal.sensitiveDigestion.title, "Gentler picks")
        XCTAssertEqual(GroceryGoal.lowSugar.productReason, "Low sugar")
    }

    func testSavedProductsPersistSnapshotsAndLists() async {
        let suiteName = "PicklyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let product = MockProductService().products[1]

        let firstStore = SavedProductsStore(defaults: defaults)
        firstStore.recordView(product)
        firstStore.toggle(product)
        await firstStore.waitForPendingPersistence()

        XCTAssertTrue(firstStore.isSaved(product))
        XCTAssertEqual(firstStore.savedProducts.map(\.productId), [product.id])
        XCTAssertEqual(firstStore.product(id: product.id), product)

        let secondStore = SavedProductsStore(defaults: defaults)
        XCTAssertEqual(secondStore.savedProducts.first?.productId, product.id)
        XCTAssertEqual(secondStore.recentProducts.first?.productId, product.id)
        XCTAssertEqual(secondStore.product(id: product.id), product)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testSavedProductsRefreshesLegacySnapshotByBarcodeWithoutChangingUserLists() async {
        let suiteName = "PicklyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let legacyProduct = makeCatalogProduct(
            id: "off-8480000213587",
            name: "Griego Ligero Natural",
            category: "Yogurt",
            score: 82,
            barcode: "8480000213587",
            brand: "Hacendado",
            categoryTags: ["en:yogurts"],
            source: .openFoodFacts
        )
        let freshCatalogProduct = makeCatalogProduct(
            id: "published-yogurt",
            name: "Light Natural Greek Yogurt",
            category: "Yogurt",
            score: 85,
            barcode: "8480000213587",
            brand: "Hacendado",
            categoryTags: ["en:yogurts"],
            source: .openFoodFacts
        )

        let store = SavedProductsStore(defaults: defaults)
        store.recordView(legacyProduct)
        store.toggle(legacyProduct)
        let savedBeforeRefresh = store.savedProducts
        let recentBeforeRefresh = store.recentProducts

        store.refreshSnapshots(from: [freshCatalogProduct])
        await store.waitForPendingPersistence()

        XCTAssertEqual(
            store.product(id: legacyProduct.id)?.name,
            "Light Natural Greek Yogurt"
        )
        XCTAssertEqual(store.product(id: legacyProduct.id)?.id, legacyProduct.id)
        XCTAssertEqual(store.savedProducts, savedBeforeRefresh)
        XCTAssertEqual(store.recentProducts, recentBeforeRefresh)

        let restoredStore = SavedProductsStore(defaults: defaults)
        XCTAssertEqual(
            restoredStore.product(id: legacyProduct.id)?.name,
            "Light Natural Greek Yogurt"
        )
        XCTAssertEqual(restoredStore.savedProducts, savedBeforeRefresh)
        XCTAssertEqual(restoredStore.recentProducts, recentBeforeRefresh)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testSavedProductsMigratesPersistedForeignSnapshotNameWithoutDeletingHistory() async throws {
        let suiteName = "PicklyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let legacyProduct = makeCatalogProduct(
            id: "off-4056489139393",
            name: "Tomatenketchup Original",
            category: "Würzmittel",
            score: 70,
            barcode: "4056489139393",
            brand: "Kania",
            categoryTags: ["en:ketchup"],
            source: .openFoodFacts
        )
        let savedEntry = SavedProduct(productId: legacyProduct.id, date: Date(timeIntervalSince1970: 123))
        let recentEntry = SavedProduct(productId: legacyProduct.id, date: Date(timeIntervalSince1970: 456))
        let persistedState = SavedProductsStateFixture(
            savedProducts: [savedEntry],
            recentProducts: [recentEntry],
            productSnapshots: [legacyProduct.id: legacyProduct]
        )
        defaults.set(
            try JSONEncoder().encode(persistedState),
            forKey: "pickly.saved-products.v1"
        )

        let store = SavedProductsStore(defaults: defaults)
        await store.waitForPendingPersistence()

        XCTAssertEqual(store.product(id: legacyProduct.id)?.name, "Kania Ketchup")
        XCTAssertEqual(store.savedProducts, [savedEntry])
        XCTAssertEqual(store.recentProducts, [recentEntry])

        let restoredStore = SavedProductsStore(defaults: defaults)
        XCTAssertEqual(restoredStore.product(id: legacyProduct.id)?.name, "Kania Ketchup")
        XCTAssertEqual(restoredStore.savedProducts, [savedEntry])
        XCTAssertEqual(restoredStore.recentProducts, [recentEntry])

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

    func testAlternativePreviewPrioritizesCuratedAndSameCategoryProducts() {
        let service = MockProductService()
        let currentProduct = service.products.first { $0.id == "honey-crunch-cereal" }!
        let curatedMatch = service.products.first { $0.id == "protein-granola" }!

        let preview = AlternativePreviewBuilder.products(
            for: currentProduct,
            alternatives: [curatedMatch, curatedMatch],
            catalog: service.products
        )

        XCTAssertEqual(Array(preview.map(\.id).prefix(2)), ["protein-granola", "simple-oat-cereal"])
        XCTAssertFalse(preview.contains { $0.id == currentProduct.id })
        XCTAssertEqual(Set(preview.map(\.id)).count, preview.count)
        XCTAssertTrue(preview.allSatisfy { !$0.isLimitedData })
        XCTAssertTrue(preview.allSatisfy { $0.category == currentProduct.category })
        XCTAssertTrue(preview.allSatisfy { ProductSimilarity.isComparable($0, to: currentProduct) })
    }

    func testAlternativePreviewIsEmptyWhenNoComparableProductsExist() {
        let service = MockProductService()
        let currentProduct = service.products.first { $0.id == "greek-yogurt" }!

        let preview = AlternativePreviewBuilder.products(
            for: currentProduct,
            alternatives: [],
            catalog: service.products
        )

        XCTAssertTrue(preview.isEmpty)
    }

    func testAlternativePreviewIncludesEqualScoreComparableProduct() {
        let currentProduct = MockProductService().products.first { $0.id == "honey-crunch-cereal" }!
        let lowerSugarMatch = Product(
            id: "lower-sugar-match",
            barcode: "999888777666",
            name: "Lower Sugar Cereal",
            brand: "Test Brand",
            category: currentProduct.category,
            imageName: "leaf.fill",
            ingredients: ["Oats"],
            nutrition: Product.Nutrition(
                sugars100g: 4,
                addedSugars100g: 4,
                salt100g: currentProduct.nutrition.salt100g,
                saturatedFat100g: currentProduct.nutrition.saturatedFat100g,
                proteins100g: currentProduct.nutrition.proteins100g,
                fiber100g: currentProduct.nutrition.fiber100g
            ),
            nutritionSummary: "4g added sugar",
            score: currentProduct.score,
            summary: "A lower sugar option.",
            reasons: ["Less added sugar"],
            warnings: [],
            positives: ["Less added sugar"],
            forYouNotes: [],
            alternativeIDs: [],
            confidence: "High"
        )

        let preview = AlternativePreviewBuilder.products(
            for: currentProduct,
            alternatives: [lowerSugarMatch],
            catalog: []
        )

        XCTAssertEqual(preview.map(\.id), [lowerSugarMatch.id])
        XCTAssertFalse(AlternativeBenefitBuilder.isBetter(lowerSugarMatch, than: currentProduct))
        XCTAssertEqual(
            AlternativeBenefitBuilder.reason(for: lowerSugarMatch, comparedTo: currentProduct),
            "Less sugar"
        )
    }

    func testAlternativePreviewUsesNutritionBenefitWhenCurrentIngredientsAreMissing() {
        let currentProduct = Product(
            id: "incomplete-tea",
            barcode: "123456789012",
            name: "Ice tea",
            brand: "Current",
            category: "Grocery",
            imageName: "takeoutbag.and.cup.and.straw.fill",
            ingredients: [],
            nutrition: Product.Nutrition(
                sugars100g: 3,
                salt100g: 0,
                saturatedFat100g: 0,
                proteins100g: 0,
                fiber100g: 0
            ),
            nutritionSummary: "3g sugar",
            score: 83,
            summary: "Incomplete ingredient data.",
            reasons: [],
            warnings: [],
            positives: [],
            forYouNotes: [],
            alternativeIDs: [],
            confidence: "Medium"
        )
        let lowerSugarMatch = Product(
            id: "complete-tea",
            barcode: "123456789013",
            name: "Lower Sugar Tea",
            brand: "Alternative",
            category: "Iced teas",
            imageName: "leaf.fill",
            ingredients: ["Water", "Tea", "Sweetener"],
            nutrition: Product.Nutrition(
                sugars100g: 0,
                salt100g: 0,
                saturatedFat100g: 0,
                proteins100g: 0,
                fiber100g: 0
            ),
            nutritionSummary: "0g sugar",
            score: 78,
            summary: "Less sugar with complete ingredient data.",
            reasons: ["Less sugar"],
            warnings: [],
            positives: ["Less sugar"],
            forYouNotes: [],
            alternativeIDs: [],
            confidence: "High"
        )

        XCTAssertFalse(AlternativeBenefitBuilder.isBetter(lowerSugarMatch, than: currentProduct))
        XCTAssertEqual(
            AlternativeBenefitBuilder.reason(for: lowerSugarMatch, comparedTo: currentProduct),
            "Less sugar"
        )
    }

    func testUnknownDietaryStatusesDoNotBecomePersonalWarnings() {
        let product = MockProductService().products[1]
        let preferences = UserPreferences(
            sensitiveDigestion: false,
            lowSugar: false,
            lowSodium: false,
            vegetarian: true,
            vegan: true,
            glutenFree: true,
            lactoseFree: true
        )

        XCTAssertTrue(product.forYouMessages(preferences: preferences).isEmpty)
    }

    func testRelatedProductQueryUsesNameForGenericGroceryCategory() {
        let product = Product(
            id: "iced-tea",
            barcode: "123456789012",
            name: "Ice tea",
            brand: "Unknown brand",
            category: "Grocery",
            imageName: "barcode.viewfinder",
            ingredients: [],
            nutrition: Product.Nutrition(sugars100g: 3),
            nutritionSummary: "Nutrition data incomplete",
            score: nil,
            summary: "Some product details are missing.",
            reasons: [],
            warnings: [],
            positives: [],
            forYouNotes: [],
            alternativeIDs: [],
            confidence: "Low"
        )

        XCTAssertEqual(RelatedProductQuery.searchText(for: product), "iced tea")
        XCTAssertEqual(
            RelatedProductQuery.searchTexts(for: product),
            ["iced tea", "sugar free iced tea", "unsweetened iced tea"]
        )
    }

    func testRelatedProductQueryUsesProductFamilyInsteadOfIncorrectCatalogCategory() {
        let crackers = makeCatalogProduct(
            id: "salted-crackers",
            name: "Crackers com sal",
            category: "Wafers",
            score: 57
        )

        XCTAssertEqual(ProductFamily.classify(crackers), .crackers)
        XCTAssertEqual(crackers.displayCategoryName, "Crackers")
        XCTAssertEqual(
            RelatedProductQuery.searchTexts(for: crackers),
            ["Crackers com sal", "salted crackers", "cream crackers"]
        )
    }

    func testProductSimilarityDoesNotTreatSweetWafersAsCrackers() {
        let crackers = makeCatalogProduct(
            id: "salted-crackers",
            name: "Crackers com sal",
            category: "Wafers",
            score: 57
        )
        let sweetWafers = makeCatalogProduct(
            id: "vanilla-wafers",
            name: "Zero wafer vanilla",
            category: "Wafers",
            score: 70
        )
        let creamCrackers = makeCatalogProduct(
            id: "cream-crackers",
            name: "Whole grain cream crackers",
            category: "Crackers",
            score: 71
        )

        XCTAssertFalse(ProductSimilarity.isComparable(sweetWafers, to: crackers))
        XCTAssertTrue(ProductSimilarity.isComparable(creamCrackers, to: crackers))
    }

    func testAlmondNamesUseNutsProductFamily() {
        let englishAlmonds = makeCatalogProduct(
            id: "almonds-natural",
            name: "Almonds natural",
            category: "Almonds",
            score: 91
        )
        let spanishAlmonds = makeCatalogProduct(
            id: "almendra-natural",
            name: "Almendra natural",
            category: "Frutos secos",
            score: 88
        )

        XCTAssertEqual(ProductFamily.classify(englishAlmonds), .nuts)
        XCTAssertEqual(ProductFamily.classify(spanishAlmonds), .nuts)
    }

    func testYogurtIsNotComparableToAlmonds() {
        let almonds = makeCatalogProduct(
            id: "almonds-natural",
            name: "Almonds natural",
            category: "Almonds",
            score: 91
        )
        let yogurt = makeCatalogProduct(
            id: "griego-ligero-natural",
            name: "Griego Ligero Natural",
            category: "Yogurt",
            score: 85
        )

        XCTAssertEqual(ProductFamily.classify(almonds), .nuts)
        XCTAssertEqual(ProductFamily.classify(yogurt), .yogurt)
        XCTAssertFalse(ProductSimilarity.isComparable(yogurt, to: almonds))
    }

    func testAlmondIngredientDoesNotTurnDrinksOrBarsIntoPlainNuts() {
        let almondDrink = makeCatalogProduct(
            id: "almond-drink",
            name: "Almond drink natural",
            category: "Almond-based drinks",
            score: 80
        )
        let almondBar = makeCatalogProduct(
            id: "almond-bar",
            name: "Natural almond bar",
            category: "Snack bars",
            score: 76
        )

        XCTAssertNotEqual(ProductFamily.classify(almondDrink), .nuts)
        XCTAssertNotEqual(ProductFamily.classify(almondBar), .nuts)
    }

    func testGenericNaturalWordDoesNotCreateProductSimilarity() {
        let current = makeCatalogProduct(
            id: "natural-snack",
            name: "Natural snack",
            category: "Grocery",
            score: 70
        )
        let candidate = makeCatalogProduct(
            id: "natural-sauce",
            name: "Natural sauce",
            category: "Grocery",
            score: 75
        )

        XCTAssertFalse(ProductSimilarity.isComparable(candidate, to: current))
    }

    func testKetchupPeersStayComparableWithoutAdmittingCokeOrSugarClaimJams() {
        let ketchup = makeCatalogProduct(
            id: "current-ketchup",
            name: "Tomato Ketchup 70%",
            category: "Ketchup",
            score: 72,
            barcode: "8715700112596",
            brand: "Heinz",
            categoryTags: ["en:ketchup"],
            source: .openFoodFacts
        )
        let ketchupPeer = makeCatalogProduct(
            id: "ketchup-peer",
            name: "Classic Tomato Ketchup",
            category: "Ketchup",
            score: 78,
            barcode: "3017620422003",
            categoryTags: ["en:ketchup"],
            source: .openFoodFacts
        )
        let cocaColaZero = makeCatalogProduct(
            id: "coca-cola-zero",
            name: "Coca-Cola Zero Sugar",
            category: "Colas",
            score: 80,
            barcode: "5449000000996",
            categoryTags: ["en:colas", "en:sodas"],
            source: .openFoodFacts
        )
        let sugarFreeJam = makeCatalogProduct(
            id: "sugar-free-jam",
            name: "Confiture de fraises sans sucre",
            category: "Strawberry jams",
            score: 82,
            barcode: "4006381333931",
            categoryTags: ["en:jams", "en:strawberry-jams"],
            source: .openFoodFacts
        )
        let reducedSugarJam = makeCatalogProduct(
            id: "reduced-sugar-jam",
            name: "Confiture de fraises moins sucre",
            category: "Strawberry jams",
            score: 81,
            barcode: "5901234123457",
            categoryTags: ["en:jams", "en:strawberry-jams"],
            source: .openFoodFacts
        )
        let sugar = makeCatalogProduct(
            id: "sugar-pack",
            name: "Sugar",
            category: "Sugars",
            score: 40,
            barcode: "1000000000016",
            categoryTags: ["en:sugars", "en:white-sugars"],
            source: .openFoodFacts
        )

        XCTAssertEqual(ProductFamily.classify(ketchup), .ketchup)
        XCTAssertEqual(ProductFamily.classify(ketchupPeer), .ketchup)
        XCTAssertEqual(ProductFamily.classify(cocaColaZero), .softDrink)
        XCTAssertNil(ProductFamily.classify(sugarFreeJam))
        XCTAssertNil(ProductFamily.classify(reducedSugarJam))
        XCTAssertEqual(ProductFamily.classify(sugar), .sugar)
        XCTAssertTrue(ProductSimilarity.isComparable(ketchupPeer, to: ketchup))
        XCTAssertFalse(ProductSimilarity.isComparable(cocaColaZero, to: ketchup))
        XCTAssertFalse(ProductSimilarity.isComparable(sugarFreeJam, to: ketchup))
        XCTAssertFalse(ProductSimilarity.isComparable(reducedSugarJam, to: ketchup))
        XCTAssertFalse(ProductSimilarity.isComparable(sugar, to: ketchup))
    }

    func testAlternativeSelectionExcludesLocalizedSelfAndDeduplicatesBarcodeFirst() {
        let current = makeCatalogProduct(
            id: "current-ketchup",
            name: "Tomato Ketchup 70%",
            category: "Ketchup",
            score: 91,
            barcode: "8715700112596",
            brand: "Heinz",
            categoryTags: ["en:ketchup"]
        )
        let localizedSelf = makeCatalogProduct(
            id: "localized-current-ketchup",
            name: "Ketchup aux tomates 70%",
            category: "Ketchup",
            score: 93,
            barcode: "8715700112596",
            brand: "Heinz",
            categoryTags: ["en:ketchup"]
        )
        let englishPeer = makeCatalogProduct(
            id: "english-peer",
            name: "Classic Tomato Ketchup",
            category: "Ketchup",
            score: 93,
            barcode: "3017620422003",
            brand: "Fixture Brand",
            categoryTags: ["en:ketchup"]
        )
        let localizedPeer = makeCatalogProduct(
            id: "localized-peer",
            name: "Ketchup classique",
            category: "Ketchup",
            score: 94,
            barcode: "3017620422003",
            brand: "Fixture Brand",
            categoryTags: ["en:ketchup"]
        )
        let distinctPeer = makeCatalogProduct(
            id: "distinct-peer",
            name: "Organic Tomato Ketchup",
            category: "Ketchup",
            score: 92,
            barcode: "4006381333931",
            brand: "Another Brand",
            categoryTags: ["en:ketchup"]
        )

        let selection = AlternativePreviewBuilder.selection(
            for: current,
            alternatives: [localizedSelf, englishPeer, localizedPeer, distinctPeer],
            catalog: []
        )

        XCTAssertTrue(ProductIdentity.isSame(localizedSelf, as: current))
        XCTAssertEqual(ProductIdentity.key(for: englishPeer), ProductIdentity.key(for: localizedPeer))
        XCTAssertEqual(selection.kind, .similar)
        XCTAssertEqual(selection.products.map(\.id), [englishPeer.id, distinctPeer.id])
        XCTAssertEqual(selection.products.map(\.barcode), ["3017620422003", "4006381333931"])
        XCTAssertEqual(Set(selection.products.map(\.barcode)).count, selection.products.count)
        XCTAssertTrue(selection.products.allSatisfy { ($0.score ?? 0) > (current.score ?? 0) })
    }

    func testBetterChoicesExcludeLowerScoredKetchupPeers() {
        let ketchup = makeCatalogProduct(
            id: "current-ketchup-81",
            name: "Tomato Ketchup",
            category: "Ketchup",
            score: 81
        )
        let lowerScoredPeers = [51, 67, 43].enumerated().map { index, score in
            makeCatalogProduct(
                id: "ketchup-peer-\(score)",
                name: "Tomato Ketchup \(index)",
                category: "Ketchup",
                score: score
            )
        }
        let higherScoredPeer = makeCatalogProduct(
            id: "ketchup-peer-84",
            name: "Reduced Sugar Tomato Ketchup",
            category: "Ketchup",
            score: 84
        )

        let selection = AlternativePreviewBuilder.selection(
            for: ketchup,
            alternatives: lowerScoredPeers + [higherScoredPeer],
            catalog: []
        )

        XCTAssertEqual(selection.kind, .similar)
        XCTAssertEqual(
            selection.products.map(\.id),
            [higherScoredPeer.id]
        )
        XCTAssertTrue(selection.products.allSatisfy { ProductSimilarity.isComparable($0, to: ketchup) })
        XCTAssertTrue(selection.products.allSatisfy { ($0.score ?? 0) >= (ketchup.score ?? 0) })
    }

    func testAlmondShelfReturnsManyUniqueSimilarNutsAndRespectsLimit() {
        let almonds = makeCatalogProduct(
            id: "current-almonds",
            name: "Almonds natural",
            category: "Almonds",
            score: 91
        )
        let nutCandidates = (0..<45).map { index in
            makeCatalogProduct(
                id: "nut-\(index)",
                name: "Natural almonds \(index)",
                category: "Nuts",
                score: 92
            )
        }
        let yogurt = makeCatalogProduct(
            id: "griego-ligero-natural",
            name: "Griego Ligero Natural",
            category: "Yogurt",
            score: 85
        )

        let selection = AlternativePreviewBuilder.selection(
            for: almonds,
            alternatives: nutCandidates + [yogurt],
            catalog: [],
            limit: 40
        )

        XCTAssertEqual(selection.kind, .similar)
        XCTAssertEqual(selection.products.count, 40)
        XCTAssertEqual(Set(selection.products.map(\.id)).count, 40)
        XCTAssertFalse(selection.products.contains { $0.id == yogurt.id })
        XCTAssertTrue(selection.products.allSatisfy { ProductFamily.classify($0) == .nuts })
        XCTAssertTrue(selection.products.allSatisfy { ($0.score ?? 0) > (almonds.score ?? 0) })
    }

    func testGreatAlmondProductStillShowsSimilarProducts() {
        let almonds = makeCatalogProduct(
            id: "current-almonds",
            name: "Almonds natural",
            category: "Almonds",
            score: 91
        )
        let higherScoredAlmonds = (0..<5).map { index in
            makeCatalogProduct(
                id: "higher-almond-\(index)",
                name: "Roasted almonds \(index)",
                category: "Almonds",
                score: 95
            )
        }

        let selection = AlternativePreviewBuilder.selection(
            for: almonds,
            alternatives: higherScoredAlmonds,
            catalog: []
        )

        XCTAssertEqual(selection.kind, .similar)
        XCTAssertEqual(selection.products.count, higherScoredAlmonds.count)
        XCTAssertTrue(selection.products.allSatisfy { ($0.score ?? 0) > (almonds.score ?? 0) })
    }

    func testRelatedProductFailureIsExposedInsteadOfMasqueradingAsEmptyCatalog() async {
        OpenFoodFactsURLProtocol.reset()
        let session = makeOpenFoodFactsSession()
        OpenFoodFactsURLProtocol.responseData = Data("{\"products\":[]}".utf8)
        OpenFoodFactsURLProtocol.statusCodeByHost = [
            "world.openfoodfacts.org": 503,
            "world.openfoodfacts.net": 200
        ]
        defer { OpenFoodFactsURLProtocol.reset() }

        let store = ProductCatalogStore(
            catalogService: CloudflareProductService(session: session),
            openFoodFactsService: OpenFoodFactsService(session: session),
            fallbackProducts: [],
            remoteEnabled: true,
            prototypeFallbackEnabled: false
        )
        let almonds = makeCatalogProduct(
            id: "current-almonds",
            name: "Almonds natural",
            category: "Almonds",
            score: 91
        )

        let products = await store.relatedProducts(for: almonds, limit: 3)

        XCTAssertTrue(products.isEmpty)
        XCTAssertNotNil(store.relatedProductsErrorMessage)
        XCTAssertFalse(OpenFoodFactsURLProtocol.requestedHosts.isEmpty)
        XCTAssertTrue(OpenFoodFactsURLProtocol.requestedHosts.allSatisfy { $0 == "world.openfoodfacts.org" })
    }

    func testSuccessfulKetchupRelatedLoadCrossesSparseCategoryPagesAndExcludesNoise() async throws {
        OpenFoodFactsURLProtocol.reset()
        defer { OpenFoodFactsURLProtocol.reset() }

        let currentBarcode = "8715700112596"
        let cokeBarcode = "5449000000996"
        let expectedPeerBarcodes = [
            "3017620422003",
            "4006381333931",
            "5901234123457",
            "1000000000016"
        ]
        let selfRecord = makeOpenFoodFactsProduct(
            code: currentBarcode,
            name: "Ketchup aux tomates 70%",
            sugars100g: 22,
            salt100g: 2.2,
            englishName: "Tomato Ketchup 70%",
            brand: "Heinz",
            categories: "Ketchup",
            categoryTags: ["en:ketchup"]
        )
        let coke = makeOpenFoodFactsProduct(
            code: cokeBarcode,
            name: "Coca-Cola Zero Sugar",
            sugars100g: 0,
            salt100g: 0.02,
            brand: "Coca-Cola",
            categories: "Colas",
            categoryTags: ["en:colas", "en:sodas"]
        )
        let firstPeer = makeOpenFoodFactsProduct(
            code: expectedPeerBarcodes[0],
            name: "Classic Tomato Ketchup",
            sugars100g: 18,
            salt100g: 1.8,
            categories: "Ketchup",
            categoryTags: ["en:ketchup"]
        )
        let secondPeer = makeOpenFoodFactsProduct(
            code: expectedPeerBarcodes[1],
            name: "Organic Tomato Ketchup",
            sugars100g: 16,
            salt100g: 1.5,
            categories: "Ketchup",
            categoryTags: ["en:ketchup"]
        )
        let duplicateFirstPeer = makeOpenFoodFactsProduct(
            code: expectedPeerBarcodes[0],
            name: "Ketchup tomate classique",
            sugars100g: 18,
            salt100g: 1.8,
            categories: "Ketchup",
            categoryTags: ["en:ketchup"]
        )
        let thirdPeer = makeOpenFoodFactsProduct(
            code: expectedPeerBarcodes[2],
            name: "Reduced Salt Tomato Ketchup",
            sugars100g: 17,
            salt100g: 1.0,
            categories: "Ketchup",
            categoryTags: ["en:ketchup"]
        )
        let fourthPeer = makeOpenFoodFactsProduct(
            code: expectedPeerBarcodes[3],
            name: "No Added Sugar Tomato Ketchup",
            sugars100g: 5,
            salt100g: 1.2,
            categories: "Ketchup",
            categoryTags: ["en:ketchup"]
        )
        let pages = [
            1: try makeOpenFoodFactsPage(
                products: [selfRecord, coke, firstPeer, secondPeer],
                count: 150,
                page: 1,
                pageSize: 50
            ),
            2: try makeOpenFoodFactsPage(
                products: [duplicateFirstPeer, thirdPeer],
                count: 150,
                page: 2,
                pageSize: 50
            ),
            3: try makeOpenFoodFactsPage(
                products: [fourthPeer],
                count: 150,
                page: 3,
                pageSize: 50
            )
        ]
        OpenFoodFactsURLProtocol.requestHandler = { request in
            let parsed = OpenFoodFactsRequest(request: request)
            guard parsed.query["categories_tags"] == "en:ketchup",
                  let page = parsed.page,
                  let data = pages[page] else {
                return .init(statusCode: 404, data: Data())
            }
            return .init(statusCode: 200, data: data)
        }

        let session = makeOpenFoodFactsSession()
        let store = makeGoalCatalogStore(session: session)
        let current = makeCatalogProduct(
            id: "current-ketchup",
            name: "Tomato Ketchup 70%",
            category: "Ketchup",
            score: 72,
            barcode: currentBarcode,
            brand: "Heinz",
            categoryTags: ["en:ketchup"],
            source: .openFoodFacts
        )

        let products = await store.relatedProducts(for: current, limit: 4)
        let requests = OpenFoodFactsURLProtocol.requestedURLs.map(OpenFoodFactsRequest.init(url:))

        XCTAssertNil(store.relatedProductsErrorMessage)
        XCTAssertEqual(products.map(\.barcode), expectedPeerBarcodes)
        XCTAssertEqual(Set(products.map(\.barcode)).count, products.count)
        XCTAssertGreaterThan(products.count, 3)
        XCTAssertFalse(products.contains { $0.barcode == currentBarcode })
        XCTAssertFalse(products.contains { $0.barcode == cokeBarcode })
        XCTAssertEqual(requests.compactMap(\.page), [1, 2, 3])
        XCTAssertTrue(requests.allSatisfy { request in
            request.host == "world.openfoodfacts.org"
                && request.path == "/api/v2/search"
                && request.query["categories_tags"] == "en:ketchup"
                && request.query["search_terms"] == nil
        })
    }

    func testCookingChocolateDoesNotRecommendChocolateBiscuits() {
        let cookingChocolate = makeCatalogProduct(
            id: "cooking-chocolate",
            name: "Chocolate para culinária",
            category: "pt:Chocolate de culinária",
            score: 49
        )
        let chocolateBiscuits = makeCatalogProduct(
            id: "chocolate-biscuits",
            name: "Belgian dark chocolate ginger thins",
            category: "Biscuits",
            score: 71
        )

        XCTAssertEqual(ProductFamily.classify(cookingChocolate), .cookingChocolate)
        XCTAssertEqual(cookingChocolate.displayCategoryName, "Cooking chocolate")
        XCTAssertFalse(ProductSimilarity.isComparable(chocolateBiscuits, to: cookingChocolate))
    }

    func testBetterChoicesExcludeLowerScoredFlourProducts() {
        let flour = makeCatalogProduct(
            id: "current-flour",
            name: "Farinha de trigo",
            category: "Flours",
            score: 90
        )
        let candidates = [
            makeCatalogProduct(id: "flour-92", name: "Whole wheat flour", category: "Flours", score: 92),
            makeCatalogProduct(id: "flour-90", name: "Wheat flour", category: "Flours", score: 90),
            makeCatalogProduct(id: "flour-88", name: "Stoneground flour", category: "Flours", score: 88)
        ]

        let selection = AlternativePreviewBuilder.selection(
            for: flour,
            alternatives: candidates,
            catalog: []
        )

        XCTAssertEqual(selection.kind, .similar)
        XCTAssertEqual(selection.products.map(\.id), ["flour-92", "flour-90"])
        XCTAssertTrue(selection.products.allSatisfy { ProductSimilarity.isComparable($0, to: flour) })
        XCTAssertTrue(selection.products.allSatisfy { ($0.score ?? 0) >= (flour.score ?? 0) })
    }

    func testPortugueseTunaUsesTunaFamilyAndUsefulCatalogQueries() {
        let tuna = makeCatalogProduct(
            id: "current-tuna",
            name: "Atum em posta em óleo vegetal",
            category: "Conservas de peixe",
            score: 75
        )
        let tunaInWater = makeCatalogProduct(
            id: "tuna-in-water",
            name: "Tuna chunks in spring water",
            category: "Canned tuna",
            score: 84
        )
        let cereal = makeCatalogProduct(
            id: "unrelated-cereal",
            name: "Whole grain cereal",
            category: "Breakfast cereals",
            score: 90
        )

        XCTAssertEqual(ProductFamily.classify(tuna), .tuna)
        XCTAssertEqual(tuna.displayCategoryName, "Tuna")
        XCTAssertTrue(RelatedProductQuery.searchTexts(for: tuna).contains("tuna in water"))
        XCTAssertTrue(ProductSimilarity.isComparable(tunaInWater, to: tuna))
        XCTAssertFalse(ProductSimilarity.isComparable(cereal, to: tuna))
    }

    func testEmptyAlternativeSelectionKeepsSimilarProductsIdentity() {
        let product = makeCatalogProduct(
            id: "current-tuna",
            name: "Atum em posta em óleo vegetal",
            category: "Conservas de peixe",
            score: 75
        )

        let selection = AlternativePreviewBuilder.selection(
            for: product,
            alternatives: [],
            catalog: []
        )

        XCTAssertEqual(selection.kind, .similar)
        XCTAssertTrue(selection.products.isEmpty)
    }

    func testAlternativeSelectionExcludesDuplicateProductRecords() {
        let current = makeCatalogProduct(
            id: "current-pasta",
            name: "Whole Wheat Penne Rigate",
            category: "Pastas",
            score: 93
        )
        let duplicateCurrent = makeCatalogProduct(
            id: "duplicate-pasta-record",
            name: "Whole Wheat Penne Rigate",
            category: "Pastas",
            score: 95
        )
        let distinctAlternative = makeCatalogProduct(
            id: "distinct-pasta",
            name: "Organic Whole Wheat Penne",
            category: "Pastas",
            score: 94
        )

        let selection = AlternativePreviewBuilder.selection(
            for: current,
            alternatives: [duplicateCurrent, distinctAlternative, distinctAlternative],
            catalog: []
        )

        XCTAssertEqual(selection.products.map(\.id), [distinctAlternative.id])
        XCTAssertFalse(selection.products.contains { $0.id == duplicateCurrent.id })
    }

    func testSimilarShelfKeepsWeakComparableProductAfterStrongerMatches() {
        let current = makeCatalogProduct(
            id: "current-biscuit",
            name: "Chocolate biscuit",
            category: "Biscuits",
            score: 32
        )
        let weakCandidate = makeCatalogProduct(
            id: "weak-biscuit",
            name: "Filled chocolate biscuit",
            category: "Biscuits",
            score: 44
        )
        let goodCandidates = [
            makeCatalogProduct(id: "biscuit-75", name: "Hazelnut biscuit", category: "Biscuits", score: 75),
            makeCatalogProduct(id: "biscuit-72", name: "Sesame biscuit", category: "Biscuits", score: 72),
            makeCatalogProduct(id: "biscuit-64", name: "Whole grain biscuit", category: "Biscuits", score: 64)
        ]

        let selection = AlternativePreviewBuilder.selection(
            for: current,
            alternatives: [weakCandidate] + goodCandidates,
            catalog: []
        )

        XCTAssertEqual(selection.kind, .similar)
        XCTAssertEqual(selection.products.last?.id, weakCandidate.id)
        XCTAssertTrue(selection.products.allSatisfy { ProductSimilarity.isComparable($0, to: current) })
    }

    func testAlternativePreviewRespectsItsLimit() {
        let service = MockProductService()
        let currentProduct = service.products.first { $0.id == "honey-crunch-cereal" }!

        let preview = AlternativePreviewBuilder.products(
            for: currentProduct,
            alternatives: service.alternatives(for: currentProduct),
            catalog: service.products,
            limit: 1
        )

        XCTAssertEqual(preview.map(\.id), ["simple-oat-cereal"])
    }

    @MainActor
    func testPicklyPlusUsesStableSubscriptionProductIDs() {
        XCTAssertEqual(
            SubscriptionStore.productIDs,
            ["com.pickly.plus.monthly", "com.pickly.plus.annual"]
        )
        XCTAssertEqual(SubscriptionStore.Plan.monthly.productID, "com.pickly.plus.monthly")
        XCTAssertEqual(SubscriptionStore.Plan.annual.productID, "com.pickly.plus.annual")
        XCTAssertEqual(
            SubscriptionStore.managementURL.absoluteString,
            "https://apps.apple.com/account/subscriptions"
        )
        XCTAssertEqual(
            SubscriptionStore.standardEULAURL.absoluteString,
            "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
        )
    }

    func testPublishedScoringMethodologyMatchesTheBaselineCalculation() {
        let result = ScoringService().evaluate(
            nutrition: Product.Nutrition(
                sugars100g: 6,
                salt100g: 0.5,
                saturatedFat100g: 2,
                proteins100g: 0,
                fiber100g: 0
            ),
            ingredients: ["Oats"],
            additivesTags: [],
            category: "Breakfast"
        )

        XCTAssertEqual(ScoringMethodology.baselineScore, 75)
        XCTAssertEqual(result.score, ScoringMethodology.baselineScore)
        XCTAssertTrue(
            String(localized: ScoringMethodology.medicalDisclaimer)
                .localizedCaseInsensitiveContains("not medical advice")
        )
    }

    func testPicklyPlusContentGateNeverOffersUnavailableContent() {
        XCTAssertEqual(
            PicklyPlusContentGate.state(isPlus: false, hasContent: false),
            .unavailable
        )
        XCTAssertEqual(
            PicklyPlusContentGate.state(isPlus: true, hasContent: false),
            .unavailable
        )
    }

    func testPicklyPlusContentGateReflectsEntitlementForAvailableContent() {
        XCTAssertEqual(
            PicklyPlusContentGate.state(isPlus: false, hasContent: true),
            .locked
        )
        XCTAssertEqual(
            PicklyPlusContentGate.state(isPlus: true, hasContent: true),
            .unlocked
        )
    }

    func testGoalRecommendationPlusShelfContainsOnlyAdditionalProducts() {
        let rankedProducts = MockProductService().products
        let freeProducts = Array(rankedProducts.prefix(4))
        let plusProducts = GoalRecommendationContentBuilder.plusProducts(
            from: rankedProducts,
            freeLimit: 4,
            plusLimit: 30
        )

        XCTAssertEqual(plusProducts.map(\.id), rankedProducts.dropFirst(4).map(\.id))
        XCTAssertTrue(Set(freeProducts.map(\.id)).isDisjoint(with: plusProducts.map(\.id)))
        XCTAssertTrue(
            GoalRecommendationContentBuilder.plusProducts(
                from: freeProducts,
                freeLimit: 4,
                plusLimit: 30
            ).isEmpty
        )
    }

    func testScoringRejectsAddedSugarThatExceedsTotalSugar() {
        let nutrition = Product.Nutrition(
            sugars100g: 10.6,
            addedSugars100g: 18.44,
            salt100g: 0,
            saturatedFat100g: 0,
            proteins100g: 0
        )

        let result = ScoringService().evaluate(
            nutrition: nutrition,
            ingredients: ["Carbonated water", "Sugar"],
            additivesTags: []
        )

        XCTAssertEqual(nutrition.sugarAssessment(ingredients: ["Sugar"]).value, 10.6)
        XCTAssertTrue(result.reasons.contains { $0.contains("looks inconsistent") })
        XCTAssertTrue(result.warnings.contains { $0.contains("lowers confidence") })
        XCTAssertFalse(result.positives.contains { $0.contains("added sugar") })
        XCTAssertTrue(result.nutritionSummary.contains("sugar"))
        XCTAssertFalse(result.nutritionSummary.contains("18.4"))
        XCTAssertEqual(result.confidence, "Medium")
    }

    func testScoringRejectsZeroAddedSugarWhenIngredientsConflict() {
        let nutrition = Product.Nutrition(
            sugars100g: 32,
            addedSugars100g: 0,
            salt100g: 0.5,
            saturatedFat100g: 5.6,
            proteins100g: 6.3,
            fiber100g: 3
        )
        let ingredients = ["Cereal", "Sugar", "Glucose syrup", "Cocoa"]

        let result = ScoringService().evaluate(
            nutrition: nutrition,
            ingredients: ingredients,
            additivesTags: []
        )

        XCTAssertEqual(nutrition.sugarAssessment(ingredients: ingredients).value, 32)
        XCTAssertTrue(result.warnings.contains("High sugar level per 100g"))
        XCTAssertFalse(result.positives.contains("Low in added sugar per 100g"))
        XCTAssertEqual(result.confidence, "Medium")
    }

    func testServerScoringPolicyRejectsStaleVersion() {
        XCTAssertFalse(
            ServerScoringPolicy.shouldUseCuratedScoring(
                version: "mvp-v1",
                nutrition: Product.Nutrition(
                    sugars100g: 3,
                    addedSugars100g: 0,
                    salt100g: 0.1,
                    saturatedFat100g: 0.5
                ),
                ingredients: ["Oats"]
            )
        )
    }

    func testServerScoringPolicyRejectsConflictingNutrition() {
        XCTAssertFalse(
            ServerScoringPolicy.shouldUseCuratedScoring(
                version: ServerScoringPolicy.currentVersion,
                nutrition: Product.Nutrition(
                    sugars100g: 10.6,
                    addedSugars100g: 18.44,
                    salt100g: 0,
                    saturatedFat100g: 0
                ),
                ingredients: ["Sugar"]
            )
        )
    }

    func testServerScoringPolicyAcceptsValidatedCurrentVersion() {
        XCTAssertTrue(
            ServerScoringPolicy.shouldUseCuratedScoring(
                version: ServerScoringPolicy.currentVersion,
                nutrition: Product.Nutrition(
                    sugars100g: 10.6,
                    salt100g: 0,
                    saturatedFat100g: 0
                ),
                ingredients: ["Carbonated water", "Sugar"]
            )
        )
    }

    func testProductRequestDraftRequiresANameOrValidBarcode() throws {
        XCTAssertThrowsError(
            try ProductRequestDraft(barcode: "", name: "", brand: "", note: "")
        ) { error in
            XCTAssertEqual(error as? ProductRequestError, .missingProductDetails)
        }

        XCTAssertThrowsError(
            try ProductRequestDraft(barcode: "123", name: "", brand: "", note: "")
        ) { error in
            XCTAssertEqual(error as? ProductRequestError, .invalidBarcode)
        }

        let draft = try ProductRequestDraft(
            barcode: " 3017620422003 ",
            name: " Nutella ",
            brand: " Ferrero ",
            note: " New size "
        )
        XCTAssertEqual(draft.barcode, "3017620422003")
        XCTAssertEqual(draft.name, "Nutella")
        XCTAssertEqual(draft.brand, "Ferrero")
        XCTAssertEqual(draft.note, "New size")
    }

    func testLowSugarGoalUsesValidatedSugarData() {
        let product = makeProduct(
            nutrition: Product.Nutrition(
                sugars100g: 32,
                addedSugars100g: 0,
                salt100g: 0.5,
                saturatedFat100g: 5.6,
                proteins100g: 6.3,
                fiber100g: 3
            ),
            ingredients: ["Cereal", "Sugar", "Glucose syrup"]
        )

        XCTAssertFalse(GroceryGoal.lowSugar.matches(product))
    }

    func testIngredientParserPreservesNestedGroups() {
        let ingredients = IngredientListParser().parse(
            "Oats, chocolate (sugar, cocoa butter), salt; vanilla"
        )

        XCTAssertEqual(
            ingredients,
            ["Oats", "chocolate (sugar, cocoa butter)", "salt", "vanilla"]
        )
    }

    func testGreatProductHasNoContradictoryRecommendations() {
        let product = makeProduct(
            nutrition: Product.Nutrition(
                sugars100g: 3.5,
                addedSugars100g: 0,
                salt100g: 0.01,
                saturatedFat100g: 0.5,
                proteins100g: 13,
                fiber100g: 3
            ),
            ingredients: ["Durum wheat semolina"]
        )

        XCTAssertEqual(product.resultHeadline, "Great choice")
        XCTAssertTrue(product.recommendations.isEmpty)
    }

    func testOnboardingCompletionPersists() {
        let suiteName = "PicklyTests.Onboarding.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let key = "test.onboarding"

        let firstStore = OnboardingStore(defaults: defaults, key: key)
        XCTAssertFalse(firstStore.hasCompletedOnboarding)

        firstStore.complete()
        let restoredStore = OnboardingStore(defaults: defaults, key: key)
        XCTAssertTrue(restoredStore.hasCompletedOnboarding)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testOnboardingCompletionIsNotOverriddenForInjectedDefaults() {
        let suiteName = "PicklyTests.Onboarding.Restore.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let key = "test.onboarding.restore"
        defaults.set(true, forKey: key)

        let store = OnboardingStore(defaults: defaults, key: key)

        XCTAssertTrue(store.hasCompletedOnboarding)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testGoogleSignInExchangesProviderTokensWithMatchingNonce() async {
        let authService = AuthServiceSpy()
        let googleProvider = GoogleSignInProviderStub()
        let store = AuthStore(
            service: authService,
            googleSignInProvider: googleProvider
        )

        await store.signInWithGoogle()

        guard
            let credentials = authService.receivedCredentials,
            let rawNonce = credentials.nonce,
            let hashedNonce = googleProvider.receivedNonce
        else {
            return XCTFail("Expected Google and Firebase nonce values.")
        }

        let expectedHash = SHA256.hash(data: Data(rawNonce.utf8))
            .map { String(format: "%02x", $0) }
            .joined()

        XCTAssertEqual(credentials.provider, .google)
        XCTAssertEqual(credentials.idToken, "google-id-token")
        XCTAssertEqual(credentials.accessToken, "google-access-token")
        XCTAssertEqual(rawNonce.count, 32)
        XCTAssertEqual(hashedNonce.count, 64)
        XCTAssertEqual(hashedNonce, expectedHash)
        XCTAssertEqual(
            store.state,
            .signedIn(
                AuthSession(
                    accessToken: "firebase-access-token",
                    refreshToken: "firebase-refresh-token",
                    user: AuthUser(id: "user-id", email: "shopper@example.com"),
                    identityProvider: .google
                )
            )
        )
    }

    func testDeleteAccountImmediatelyClearsSignedInStateAfterServerSuccess() async {
        let authService = AuthServiceSpy()
        let googleProvider = GoogleSignInProviderStub()
        let store = AuthStore(
            service: authService,
            googleSignInProvider: googleProvider
        )

        await store.signInWithGoogle()
        let wasDeleted = await store.deleteAccount()

        XCTAssertTrue(wasDeleted)
        XCTAssertEqual(store.state, .signedOut)
        XCTAssertEqual(store.statusMessage, "Your account was deleted.")
    }

    func testDeleteAccountFailureKeepsSessionAndSurfacesError() async {
        let authService = AuthServiceSpy()
        authService.deleteError = AuthServiceError.requestFailed("503: Account deletion failed.")
        let store = AuthStore(
            service: authService,
            googleSignInProvider: GoogleSignInProviderStub()
        )

        await store.signInWithGoogle()
        let signedInState = store.state
        let wasDeleted = await store.deleteAccount()

        XCTAssertFalse(wasDeleted)
        XCTAssertEqual(store.state, signedInState)
        XCTAssertEqual(store.statusMessage, "503: Account deletion failed.")
    }

    func testAppleDeleteRequiresFreshReauthenticationBeforeCallingService() async {
        let authService = AuthServiceSpy()
        authService.restoredSession = AuthSession(
            accessToken: "apple-access-token",
            refreshToken: nil,
            user: AuthUser(id: "apple-user", email: "apple@example.com"),
            identityProvider: .apple
        )
        let store = AuthStore(
            service: authService,
            googleSignInProvider: GoogleSignInProviderStub()
        )

        await store.restoreSessionIfNeeded()
        let wasDeleted = await store.deleteAccount()

        XCTAssertFalse(wasDeleted)
        XCTAssertTrue(store.requiresAppleReauthentication)
        XCTAssertEqual(authService.deleteCallCount, 0)
        XCTAssertEqual(
            store.statusMessage,
            "For your security, confirm with Apple before deleting your account."
        )
    }

    func testPasswordResetRequestsFirebaseEmail() async {
        let authService = AuthServiceSpy()
        let store = AuthStore(
            service: authService,
            googleSignInProvider: GoogleSignInProviderStub()
        )

        await store.requestPasswordReset(email: "shopper@example.com")
        XCTAssertEqual(authService.requestedResetEmail, "shopper@example.com")
        XCTAssertEqual(
            store.statusMessage,
            "Check your email for a secure password reset link, then return to Pickly to sign in."
        )
    }

    func testAppleCancellationClearsStaleStatus() async {
        let store = AuthStore()
        store.statusMessage = "Apple sign-in couldn't be completed."

        await store.completeAppleSignIn(
            .failure(ASAuthorizationError(.canceled))
        )

        XCTAssertNil(store.statusMessage)
    }

#if targetEnvironment(simulator)
    func testAppleUnavailableInSimulatorDoesNotLeaveStatus() async {
        let store = AuthStore()
        store.statusMessage = "Previous authentication message"

        await store.completeAppleSignIn(
            .failure(ASAuthorizationError(.unknown))
        )

        XCTAssertNil(store.statusMessage)
    }

    func testNonceGeneratorReturnsRecoverableErrorWhenEntropyFails() {
        XCTAssertThrowsError(
            try AuthStore.makeNonce(length: 32) {
                throw AuthStore.NonceError.secureRandomUnavailable(errSecNotAvailable)
            }
        ) { error in
            XCTAssertEqual(
                error as? AuthStore.NonceError,
                .secureRandomUnavailable(errSecNotAvailable)
            )
            XCTAssertEqual(
                (error as? LocalizedError)?.errorDescription,
                "Secure sign-in couldn't start. Please try again."
            )
        }
    }

    func testNonceGeneratorRejectsInvalidLength() {
        XCTAssertThrowsError(
            try AuthStore.makeNonce(length: 0, randomByte: { 0 })
        ) { error in
            XCTAssertEqual(error as? AuthStore.NonceError, .invalidLength)
        }
    }
#endif

    private func makeProduct(
        nutrition: Product.Nutrition,
        ingredients: [String]
    ) -> Product {
        let scoring = ScoringService().evaluate(
            nutrition: nutrition,
            ingredients: ingredients,
            additivesTags: []
        )

        return Product(
            id: UUID().uuidString,
            barcode: "12345670",
            name: "Test product",
            brand: "Test brand",
            category: "Grocery",
            imageName: "basket",
            ingredients: ingredients,
            nutrition: nutrition,
            nutritionSummary: scoring.nutritionSummary,
            score: scoring.score,
            summary: scoring.summary,
            reasons: scoring.reasons,
            warnings: scoring.warnings,
            positives: scoring.positives,
            forYouNotes: scoring.forYouNotes,
            alternativeIDs: [],
            confidence: scoring.confidence
        )
    }

    private func makeOpenFoodFactsSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OpenFoodFactsURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func makeGoalCatalogStore(session: URLSession) -> ProductCatalogStore {
        ProductCatalogStore(
            catalogService: CloudflareProductService(session: session),
            openFoodFactsService: OpenFoodFactsService(session: session),
            fallbackProducts: [],
            remoteEnabled: true,
            prototypeFallbackEnabled: false
        )
    }

    private func makeOpenFoodFactsPage(
        products: [[String: Any]],
        count: Int,
        page: Int,
        pageSize: Int
    ) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "products": products,
                "count": count,
                "page": page,
                "page_size": pageSize
            ]
        )
    }

    private func makeOpenFoodFactsProduct(
        code: String,
        name: String,
        sugars100g: Double,
        salt100g: Double,
        labels: [String] = [],
        englishName: String? = nil,
        brand: String = "Fixture Brand",
        categories: String = "Fixture groceries",
        categoryTags: [String] = ["en:fixture-groceries"],
        language: String = "en",
        genericEnglishName: String? = nil
    ) -> [String: Any] {
        var product: [String: Any] = [
            "code": code,
            "product_name": name,
            "lang": language,
            "brands": brand,
            "categories": categories,
            "categories_tags": categoryTags,
            "image_front_url": "https://example.com/\(code).jpg",
            "ingredients": [
                [
                    "id": "en:fixture-ingredient",
                    "text": "Fixture ingredient"
                ]
            ],
            "ingredients_text": "Fixture ingredient",
            "nutriments": [
                "sugars_100g": sugars100g,
                "salt_100g": salt100g,
                "saturated-fat_100g": 1.0,
                "proteins_100g": 4.0,
                "fiber_100g": 2.0
            ],
            "additives_tags": [],
            "labels_tags": labels,
            "allergens_tags": [],
            "traces_tags": []
        ]
        if let englishName {
            product["product_name_en"] = englishName
        }
        if let genericEnglishName {
            product["generic_name_en"] = genericEnglishName
        }
        return product
    }

    private func makeGoalFixtureProduct(
        id: String,
        barcode: String? = nil,
        category: String = "Fixture groceries",
        sugars100g: Double = 3,
        salt100g: Double = 0.2,
        saturatedFat100g: Double = 1,
        score: Int = 80,
        summary: String = "Fixture summary",
        ingredients: [String] = ["Fixture ingredient"],
        declaredIngredientCount: Int? = nil,
        alternativeIDs: [String] = [],
        dietary: DietaryAttributes = .unknown,
        source: ProductSource = .unknown
    ) -> Product {
        Product(
            id: id,
            barcode: barcode ?? id,
            name: id,
            brand: "Fixture Brand",
            category: category,
            imageName: "basket",
            imageURL: URL(string: "https://example.com/\(id).jpg"),
            ingredients: ingredients,
            declaredIngredientCount: declaredIngredientCount,
            nutrition: Product.Nutrition(
                sugars100g: sugars100g,
                salt100g: salt100g,
                saturatedFat100g: saturatedFat100g,
                proteins100g: 4,
                fiber100g: 2
            ),
            nutritionSummary: "Fixture nutrition",
            score: score,
            summary: summary,
            reasons: ["Fixture reason"],
            warnings: [],
            positives: ["Fixture positive"],
            forYouNotes: [],
            alternativeIDs: alternativeIDs,
            confidence: "High",
            dietary: dietary,
            source: source
        )
    }

    private func makeCatalogProduct(
        id: String,
        name: String,
        category: String,
        score: Int,
        barcode: String? = nil,
        brand: String = "Test brand",
        categoryTags: [String] = [],
        source: ProductSource = .mock
    ) -> Product {
        Product(
            id: id,
            barcode: barcode ?? id,
            name: name,
            brand: brand,
            category: category,
            categoryTags: categoryTags,
            imageName: "basket",
            ingredients: ["Ingredient"],
            nutrition: Product.Nutrition(
                sugars100g: 3,
                salt100g: 0.2,
                saturatedFat100g: 0.5,
                proteins100g: 5,
                fiber100g: 3
            ),
            nutritionSummary: "Test nutrition",
            score: score,
            summary: "Test product",
            reasons: [],
            warnings: [],
            positives: [],
            forYouNotes: [],
            alternativeIDs: [],
            confidence: "High",
            source: source
        )
    }
}

private struct SavedProductsStateFixture: Codable {
    let savedProducts: [SavedProduct]
    let recentProducts: [SavedProduct]
    let productSnapshots: [String: Product]
}

private final class OpenFoodFactsURLProtocol: URLProtocol {
    struct StubResponse {
        let statusCode: Int
        let data: Data
    }

    nonisolated(unsafe) static var responseData: Data?
    nonisolated(unsafe) static var statusCodeByHost: [String: Int] = [:]
    nonisolated(unsafe) static var requestedHosts: [String] = []
    nonisolated(unsafe) static var requestedURLs: [URL] = []
    nonisolated(unsafe) static var requestHandler: ((URLRequest) -> StubResponse)?

    static func reset() {
        responseData = nil
        statusCodeByHost = [:]
        requestedHosts = []
        requestedURLs = []
        requestHandler = nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "world.openfoodfacts.net"
            || request.url?.host == "world.openfoodfacts.org"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        Self.requestedURLs.append(url)
        Self.requestedHosts.append(url.host ?? "")

        let stub: StubResponse
        if let requestHandler = Self.requestHandler {
            stub = requestHandler(request)
        } else if let responseData = Self.responseData {
            stub = StubResponse(
                statusCode: Self.statusCodeByHost[url.host ?? ""] ?? 200,
                data: responseData
            )
        } else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        guard let response = HTTPURLResponse(
            url: url,
            statusCode: stub.statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private struct OpenFoodFactsRequest {
    let host: String?
    let path: String
    let query: [String: String]

    init(request: URLRequest) {
        self.init(url: request.url)
    }

    init(url: URL?) {
        host = url?.host
        path = url?.path ?? ""
        let components = url.flatMap {
            URLComponents(url: $0, resolvingAgainstBaseURL: false)
        }
        query = Dictionary(
            uniqueKeysWithValues: (components?.queryItems ?? []).compactMap { item in
                item.value.map { (item.name, $0) }
            }
        )
    }

    var taxonomyTag: String? {
        query["nutrient_levels_tags"] ?? query["labels_tags"]
    }

    var page: Int? {
        query["page"].flatMap(Int.init)
    }
}

@MainActor
private final class AuthServiceSpy: AuthService {
    var isConfigured = true
    var receivedCredentials: IdentityTokenCredentials?
    var deleteError: Error?
    var deleteCallCount = 0
    var restoredSession: AuthSession?
    var requestedResetEmail: String?

    func restoreSession() async throws -> AuthSession? {
        restoredSession
    }

    func signUp(email: String, password: String) async throws -> EmailAuthResult {
        throw AuthServiceError.invalidResponse
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        throw AuthServiceError.invalidResponse
    }

    func requestPasswordReset(email: String) async throws {
        requestedResetEmail = email
    }

    func signIn(with credentials: IdentityTokenCredentials) async throws -> AuthSession {
        receivedCredentials = credentials
        return AuthSession(
            accessToken: "firebase-access-token",
            refreshToken: "firebase-refresh-token",
            user: AuthUser(id: "user-id", email: "shopper@example.com"),
            identityProvider: credentials.provider
        )
    }

    func signOut(session: AuthSession) async throws {}

    func deleteAccount(session: AuthSession) async throws {
        deleteCallCount += 1
        if let deleteError {
            throw deleteError
        }
    }
}

@MainActor
private final class GoogleSignInProviderStub: GoogleSignInProviding {
    var isConfigured = true
    var receivedNonce: String?

    func signIn(nonce: String) async throws -> GoogleIdentityTokens {
        receivedNonce = nonce
        return GoogleIdentityTokens(
            idToken: "google-id-token",
            accessToken: "google-access-token"
        )
    }

    func signOut() {}

    func disconnect() async throws {}
}
