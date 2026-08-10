import AuthenticationServices
import CryptoKit
import Security
import XCTest
@testable import Pickly

@MainActor
final class PicklyTests: XCTestCase {
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

    func testSensitiveDigestionGoalUsesGentlerPicksTitle() {
        XCTAssertEqual(GroceryGoal.sensitiveDigestion.title, "Gentler picks")
        XCTAssertEqual(GroceryGoal.lowSugar.productReason, "Low added sugar")
    }

    func testSavedProductsPersistSnapshotsAndLists() {
        let suiteName = "PicklyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let product = MockProductService().products[1]

        let firstStore = SavedProductsStore(defaults: defaults)
        firstStore.recordView(product)
        firstStore.toggle(product)

        XCTAssertTrue(firstStore.isSaved(product))
        XCTAssertEqual(firstStore.savedProducts.map(\.productId), [product.id])
        XCTAssertEqual(firstStore.product(id: product.id), product)

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
            return XCTFail("Expected Google and Supabase nonce values.")
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
                    accessToken: "supabase-access-token",
                    refreshToken: "supabase-refresh-token",
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

    func testPasswordRecoveryCompletesThroughDeepLink() async {
        let authService = AuthServiceSpy()
        let store = AuthStore(
            service: authService,
            googleSignInProvider: GoogleSignInProviderStub()
        )

        await store.requestPasswordReset(email: "shopper@example.com")
        XCTAssertEqual(authService.requestedResetEmail, "shopper@example.com")
        XCTAssertEqual(store.statusMessage, "Check your email for a password reset link.")

        let handled = await store.handleIncomingURL(
            URL(string: "pickly://auth/reset-password?code=test")!
        )
        XCTAssertTrue(handled)
        XCTAssertTrue(store.isRecoveringPassword)

        let updated = await store.updatePassword("a-secure-password")
        XCTAssertTrue(updated)
        XCTAssertEqual(authService.updatedPassword, "a-secure-password")
        XCTAssertEqual(store.statusMessage, "Password updated.")
    }

    func testUnrelatedDeepLinkIsNotConsumedByAuth() async {
        let store = AuthStore(
            service: AuthServiceSpy(),
            googleSignInProvider: GoogleSignInProviderStub()
        )

        let wasHandled = await store.handleIncomingURL(
            URL(string: "pickly://product/123")!
        )
        XCTAssertFalse(wasHandled)
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
}

@MainActor
private final class AuthServiceSpy: AuthService {
    var isConfigured = true
    var receivedCredentials: IdentityTokenCredentials?
    var deleteError: Error?
    var requestedResetEmail: String?
    var updatedPassword: String?

    private let stubSession = AuthSession(
        accessToken: "supabase-access-token",
        refreshToken: "supabase-refresh-token",
        user: AuthUser(id: "user-id", email: "shopper@example.com")
    )

    func restoreSession() async throws -> AuthSession? {
        nil
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

    func completePasswordRecovery(from url: URL) async throws -> AuthSession {
        stubSession
    }

    func updatePassword(_ password: String) async throws -> AuthSession {
        updatedPassword = password
        return stubSession
    }

    func signIn(with credentials: IdentityTokenCredentials) async throws -> AuthSession {
        receivedCredentials = credentials
        return AuthSession(
            accessToken: "supabase-access-token",
            refreshToken: "supabase-refresh-token",
            user: AuthUser(id: "user-id", email: "shopper@example.com"),
            identityProvider: credentials.provider
        )
    }

    func storeAppleAuthorizationCode(_ authorizationCode: String, session: AuthSession) async throws {}

    func signOut(session: AuthSession) async throws {}

    func deleteAccount(session: AuthSession) async throws {
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
