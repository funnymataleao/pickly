import Foundation
import NaturalLanguage

@MainActor
protocol ProductService {
    var products: [Product] { get }
    var relatedProductsErrorMessage: String? { get }

    func searchProducts(matching query: String) -> [Product]
    func product(id: String) -> Product?
    func alternatives(for product: Product) -> [Product]
    func relatedProducts(for product: Product, limit: Int) async -> [Product]
}

protocol ProductLookupService {
    func fetchProduct(barcode: String) async throws -> Product
}

extension ProductService {
    var relatedProductsErrorMessage: String? { nil }

    func searchProducts(matching query: String) -> [Product] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else {
            return products
        }

        return products.filter { product in
            product.name.localizedCaseInsensitiveContains(trimmedQuery)
                || product.brand.localizedCaseInsensitiveContains(trimmedQuery)
                || product.category.localizedCaseInsensitiveContains(trimmedQuery)
                || product.barcode.contains(trimmedQuery)
        }
    }

    func product(id: String) -> Product? {
        products.first { $0.id == id }
    }

    func alternatives(for product: Product) -> [Product] {
        product.alternativeIDs.compactMap(product(id:))
    }

    func relatedProducts(for product: Product, limit: Int) async -> [Product] {
        RelatedProductRanker.products(
            for: product,
            explicitAlternatives: alternatives(for: product),
            catalog: products,
            limit: limit
        )
    }
}

nonisolated enum RelatedProductRanker {
    static func products(
        for currentProduct: Product,
        explicitAlternatives: [Product],
        catalog: [Product],
        limit: Int
    ) -> [Product] {
        guard limit > 0 else { return [] }

        var seenKeys = Set([ProductIdentity.key(for: currentProduct)])
        var result: [Product] = []

        func appendUnique(_ product: Product) {
            guard result.count < limit,
                  !ProductIdentity.isSame(product, as: currentProduct),
                  ProductSimilarity.isComparable(product, to: currentProduct),
                  seenKeys.insert(ProductIdentity.key(for: product)).inserted else { return }
            result.append(product)
        }

        explicitAlternatives.forEach(appendUnique)

        let eligibleProducts = catalog.filter { product in
            product.name != "Unknown product"
                && (product.imageURL != nil || product.source == .mock)
                && ProductSimilarity.isComparable(product, to: currentProduct)
        }
        let currentScore = currentProduct.score
        let ranked = eligibleProducts.sorted { lhs, rhs in
            let lhsSameCategory = lhs.category.caseInsensitiveCompare(currentProduct.category) == .orderedSame
            let rhsSameCategory = rhs.category.caseInsensitiveCompare(currentProduct.category) == .orderedSame
            if lhsSameCategory != rhsSameCategory {
                return lhsSameCategory
            }

            let lhsDistance = scoreDistance(from: currentScore, to: lhs.score)
            let rhsDistance = scoreDistance(from: currentScore, to: rhs.score)
            if lhsDistance != rhsDistance {
                return lhsDistance < rhsDistance
            }

            return (lhs.score ?? -1) > (rhs.score ?? -1)
        }

        ranked.forEach(appendUnique)
        return result
    }

    private static func scoreDistance(from currentScore: Int?, to candidateScore: Int?) -> Int {
        guard let currentScore, let candidateScore else { return .max }
        return abs(currentScore - candidateScore)
    }

}

nonisolated enum RelatedProductQuery {
    static func searchText(for product: Product) -> String {
        searchTexts(for: product).first ?? product.name
    }

    static func searchTexts(for product: Product) -> [String] {
        let queries: [String]
        if let family = ProductFamily.classify(product) {
            queries = family.searchQueries(for: product)
        } else if ProductText.hasSpecificCategory(product.category) {
            // A concrete catalog category is a much stronger signal than a
            // marketing adjective in the product name (for example, "natural").
            queries = [product.category, product.name]
        } else {
            queries = [product.name]
        }

        var seen = Set<String>()
        return queries
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 && seen.insert(ProductText.normalized($0)).inserted }
    }

    static func categoryTags(for product: Product) -> [String] {
        ProductFamily.classify(product)?.categoryTags(for: product) ?? []
    }

    static func cacheKey(for product: Product) -> String {
        if let family = ProductFamily.classify(product) {
            if let categoryTag = family.categoryTags(for: product).first {
                return "family:\(family.rawValue)|\(categoryTag)"
            }
            return "family:\(family.rawValue)"
        }

        let category = ProductText.normalized(product.category)
        if ProductText.hasSpecificCategory(category) {
            return "category:\(category)"
        }

        return "query:\(ProductText.normalized(searchText(for: product)))"
    }

    static func preferredCountryTags(regionCode: String? = Locale.current.region?.identifier) -> [String] {
        PicklyLocaleContext(
            language: PicklyLanguage.resolve(),
            regionCode: regionCode
        ).preferredCountryTags
    }
}

nonisolated enum ProductIdentity {
    static func isSame(_ candidate: Product, as current: Product) -> Bool {
        if candidate.id == current.id { return true }

        let candidateBarcode = BarcodeValidator.normalize(candidate.barcode)
        let currentBarcode = BarcodeValidator.normalize(current.barcode)
        if let candidateBarcode, let currentBarcode, candidateBarcode == currentBarcode {
            return true
        }

        return key(for: candidate) == key(for: current)
    }

    static func key(for product: Product) -> String {
        if let barcode = BarcodeValidator.normalize(product.barcode) {
            return "barcode:\(barcode)"
        }

        let name = ProductText.normalized(product.name)
        let brand = ProductText.normalized(product.brand)
        if !name.isEmpty {
            return "product:\(brand)|\(name)"
        }
        return "id:\(product.id)"
    }
}

nonisolated enum ProductFamily: String, Sendable {
    case tuna
    case flour
    case crackers
    case wafers
    case cookingChocolate
    case chocolate
    case sugar
    case icedTea
    case cereal
    case yogurt
    case milk
    case cheese
    case bread
    case pasta
    case rice
    case juice
    case softDrink
    case ketchup
    case cookies
    case nuts

    static func classify(_ product: Product) -> ProductFamily? {
        let categoryTags = Set(product.categoryTags.map { $0.lowercased() })
        if !categoryTags.isDisjoint(with: ["en:ketchup", "en:tomato-ketchup"]) {
            return .ketchup
        }
        if !categoryTags.isDisjoint(with: ["en:sugars", "en:white-sugars", "en:brown-sugars", "en:granulated-sugars", "en:powdered-sugars"]) {
            return .sugar
        }

        let name = ProductText.normalized(product.name)
        let category = ProductText.normalized(product.category)
        let combined = "\(name) \(category)"

        if ProductText.containsAny(category, terms: ["ketchup", "tomato ketchup"])
            || ProductText.containsAny(name, terms: ["ketchup"]) {
            return .ketchup
        }
        if ProductText.containsAny(combined, terms: [
            "tuna", "atum", "thon", "tonno", "atun", "bonito"
        ]) {
            return .tuna
        }
        if ProductText.containsAny(combined, terms: [
            "cracker", "cream cracker", "salted biscuit", "bolacha salgada",
            "biscoito salgado", "galleta salada"
        ]) {
            return .crackers
        }
        if ProductText.containsAny(combined, terms: ["wafer", "barquillo", "gaufrette", "wafel"]) {
            return .wafers
        }
        if ProductText.containsAny(combined, terms: ["flour", "farinha", "harina", "farine", "farina"]) {
            return .flour
        }
        if ProductText.containsAny(combined, terms: ["iced tea", "ice tea", "cha gelado", "te helado"]) {
            return .icedTea
        }
        if ProductText.containsAny(combined, terms: ["chocolate para culinaria", "cooking chocolate", "baking chocolate", "chocolate de culinaria", "chocolate para reposteria", "couverture chocolate"]) {
            return .cookingChocolate
        }
        if ProductText.containsAny(combined, terms: ["cookie", "cookies", "biscuit", "biscuits", "bolacha", "biscoito", "galleta"]) {
            return .cookies
        }
        if ProductText.containsAny(combined, terms: ["chocolate", "chocolat", "cacao", "cocoa"]) {
            return .chocolate
        }
        if ProductText.containsAny(combined, terms: ["cereal", "granola", "muesli"]) { return .cereal }
        if ProductText.containsAny(combined, terms: ["yogurt", "yoghurt", "iogurte", "yaourt"]) { return .yogurt }
        if ProductText.containsAny(combined, terms: ["cheese", "queijo", "fromage", "queso"]) { return .cheese }
        if ProductText.containsAny(combined, terms: ["bread", "pao", "pain", "pan de "]) { return .bread }
        if ProductText.containsAny(combined, terms: ["pasta", "spaghetti", "macaroni", "massa alimenticia"]) { return .pasta }
        if ProductText.containsAny(combined, terms: ["rice", "arroz", "riz"]) { return .rice }
        if ProductText.containsAny(combined, terms: ["juice", "sumo", "jugo", "jus de "]) { return .juice }
        if ProductText.containsAny(combined, terms: ["soft drink", "soda", "refrigerante", "cola drink", "coca cola", "coca-cola"]) { return .softDrink }
        if ProductText.containsAny(combined, terms: ["milk", "leite", "lait", "leche"]) { return .milk }
        if isPlainNutProduct(name: name, category: category) {
            return .nuts
        }
        if isSugar(name: name, category: category) {
            return .sugar
        }
        return nil
    }

    var displayName: String {
        switch self {
        case .tuna: "Tuna"
        case .flour: "Flour"
        case .crackers: "Crackers"
        case .wafers: "Wafers"
        case .cookingChocolate: "Cooking chocolate"
        case .chocolate: "Chocolate"
        case .sugar: "Sugar"
        case .icedTea: "Iced tea"
        case .cereal: "Cereal"
        case .yogurt: "Yogurt"
        case .milk: "Milk"
        case .cheese: "Cheese"
        case .bread: "Bread"
        case .pasta: "Pasta"
        case .rice: "Rice"
        case .juice: "Juice"
        case .softDrink: "Soft drinks"
        case .ketchup: "Ketchup"
        case .cookies: "Cookies"
        case .nuts: "Nuts"
        }
    }

    func searchQueries(for product: Product) -> [String] {
        switch self {
        case .tuna:
            [product.name, "tuna in water", "canned tuna", "tuna in olive oil"]
        case .flour:
            [product.name, "wheat flour", "whole wheat flour"]
        case .crackers:
            [product.name, "salted crackers", "cream crackers"]
        case .wafers:
            [product.name, "wafer biscuits"]
        case .cookingChocolate:
            [product.name, "cooking chocolate", "dark baking chocolate"]
        case .chocolate:
            [product.name, "chocolate"]
        case .sugar:
            [product.name, "white sugar", "granulated sugar"]
        case .icedTea:
            ["iced tea", "sugar free iced tea", "unsweetened iced tea"]
        case .cereal:
            [product.name, "breakfast cereal", "whole grain cereal"]
        case .yogurt:
            [product.name, "yogurt"]
        case .milk:
            [product.name, "milk"]
        case .cheese:
            [product.name, "cheese"]
        case .bread:
            [product.name, "bread", "whole grain bread"]
        case .pasta:
            [product.name, "pasta", "whole wheat pasta"]
        case .rice:
            [product.name, "rice", "brown rice"]
        case .juice:
            [product.name, "fruit juice"]
        case .softDrink:
            [product.name, "soft drink"]
        case .ketchup:
            ["ketchup", "tomato ketchup"]
        case .cookies:
            [product.name, "biscuits", "cookies"]
        case .nuts:
            if Self.isAlmondProduct(product) {
                [product.name, "almonds", "raw almonds", "unsalted almonds"]
            } else {
                [product.name, "nuts", "mixed nuts"]
            }
        }
    }

    func categoryTags(for product: Product) -> [String] {
        switch self {
        case .ketchup:
            ["en:ketchup"]
        case .nuts where Self.isAlmondProduct(product):
            ["en:almonds"]
        case .nuts:
            ["en:nuts"]
        default:
            Array(ProductText.orderedStrongCategoryTags(in: product.categoryTags).suffix(2).reversed())
        }
    }

    private static func isSugar(name: String, category: String) -> Bool {
        let exactSugarNames = Set([
            "sugar", "white sugar", "brown sugar", "granulated sugar", "powdered sugar",
            "acucar", "azucar", "sucre", "zucchero"
        ])
        if exactSugarNames.contains(name) { return true }

        // Nutrition claims such as "zero sugar" or "70% less sugar" describe
        // a product; they must never redefine its grocery family.
        return ProductText.containsAny(category, terms: [
            "sugars", "white sugars", "brown sugars", "acucares", "azucares"
        ])
    }

    private static func isAlmondProduct(_ product: Product) -> Bool {
        let combined = "\(ProductText.normalized(product.name)) \(ProductText.normalized(product.category))"
        return ProductText.containsAny(combined, terms: almondTerms)
    }

    private static func isPlainNutProduct(name: String, category: String) -> Bool {
        let combined = "\(name) \(category)"
        let tokens = Set(combined.split(separator: " ").map(String.init))
        let hasGenericNutToken = !tokens.isDisjoint(with: ["nut", "nuts"])
        guard hasGenericNutToken || ProductText.containsAny(combined, terms: specificNutTerms) else {
            return false
        }

        // Nuts used as an ingredient do not make a drink, bar, spread, dessert,
        // or oil comparable with a bag of whole nuts.
        let excludedForms = [
            "drink", "drinks", "beverage", "beverages", "bebida", "bebidas", "boisson",
            "yogurt", "yoghurt", "iogurte", "yaourt",
            "bar", "bars", "barra", "barras",
            "spread", "butter", "manteiga", "beurre", "creme", "cream",
            "flour", "farinha", "harina", "farine",
            "oil", "oleo", "aceite", "huile",
            "dessert", "cake", "bolo", "gateau"
        ]
        return !ProductText.containsAny(combined, terms: excludedForms)
    }

    private static let almondTerms = [
        "almond", "almonds", "almendra", "almendras", "amendoa", "amendoas",
        "amande", "amandes", "mandel", "mandeln", "mandorla", "mandorle"
    ]

    private static let specificNutTerms = almondTerms + [
        "mixed nuts", "shelled nuts", "frutos secos",
        "cashew", "cashews", "caju", "anacardo", "anacardos",
        "walnut", "walnuts", "noz", "nozes", "nuez", "nueces",
        "hazelnut", "hazelnuts", "avela", "avelas", "avellana", "avellanas",
        "pistachio", "pistachios", "pistache", "pistaches",
        "pecan", "pecans", "peanut", "peanuts", "amendoim", "amendoins"
    ]
}

nonisolated enum ProductSimilarity {
    static func isComparable(_ candidate: Product, to current: Product) -> Bool {
        if let currentFamily = ProductFamily.classify(current) {
            return ProductFamily.classify(candidate) == currentFamily
        }

        let currentTaxonomy = ProductText.strongCategoryTags(in: current.categoryTags)
        let candidateTaxonomy = ProductText.strongCategoryTags(in: candidate.categoryTags)
        if !currentTaxonomy.isEmpty || !candidateTaxonomy.isEmpty {
            guard !currentTaxonomy.isEmpty, !candidateTaxonomy.isEmpty else { return false }
            return !currentTaxonomy.isDisjoint(with: candidateTaxonomy)
        }

        // Live OFF recommendations are a paid trust surface. If taxonomy is
        // missing, fail closed instead of guessing from marketing copy.
        if current.source == .openFoodFacts || candidate.source == .openFoodFacts {
            return false
        }

        let currentCategoryTokens = ProductText.categoryTokens(in: current.category)
        let candidateCategoryTokens = ProductText.categoryTokens(in: candidate.category)
        if !currentCategoryTokens.isEmpty, !candidateCategoryTokens.isEmpty {
            return !currentCategoryTokens.isDisjoint(with: candidateCategoryTokens)
        }

        // If only the candidate has a known semantic family, a generic word in
        // the current product name is not enough to cross into that family.
        guard ProductFamily.classify(candidate) == nil else { return false }

        let currentTokens = ProductText.meaningfulTokens(in: current.name)
        let candidateTokens = ProductText.meaningfulTokens(in: candidate.name)
        return !currentTokens.isEmpty && !currentTokens.isDisjoint(with: candidateTokens)
    }
}

nonisolated enum ProductText {
    static func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .split { !$0.isLetter && !$0.isNumber }
            .joined(separator: " ")
    }

    static func containsAny(_ value: String, terms: [String]) -> Bool {
        terms.contains { value.contains(normalized($0)) }
    }

    static func meaningfulTokens(in value: String) -> Set<String> {
        let ignored = Set([
            "food", "foods", "product", "products", "grocery", "groceries",
            "with", "without", "para", "com", "sem", "the", "and", "de", "da", "do",
            "natural", "nature", "original", "classic", "classico", "clasico",
            "plain", "light", "ligero", "ligeiro", "organic", "bio", "premium"
        ])
        return Set(
            normalized(value)
                .split(separator: " ")
                .map(String.init)
                .filter { $0.count > 2 && !ignored.contains($0) }
        )
    }

    static func categoryTokens(in category: String) -> Set<String> {
        meaningfulTokens(in: category)
    }

    static func hasSpecificCategory(_ category: String) -> Bool {
        !categoryTokens(in: category).isEmpty
    }

    static func strongCategoryTags(in tags: [String]) -> Set<String> {
        Set(orderedStrongCategoryTags(in: tags))
    }

    static func orderedStrongCategoryTags(in tags: [String]) -> [String] {
        let broadTags = Set([
            "en:foods", "en:groceries", "en:plant-based-foods-and-beverages",
            "en:plant-based-foods", "en:beverages", "en:dairies",
            "en:condiments", "en:sauces", "en:tomato-sauces",
            "en:snacks", "en:breakfasts", "en:cereals-and-potatoes"
        ])
        var seen = Set<String>()
        return tags
            .map { $0.lowercased() }
            .filter { !broadTags.contains($0) && seen.insert($0).inserted }
    }
}

/// Produces a name that is safe to present in Pickly's English UI.
///
/// Open Food Facts language-suffixed fields and catalog rows are user-provided
/// data, so their field name alone is not proof of the text's language. This
/// resolver intentionally fails open for opaque, brand-like names when language
/// identification is inconclusive, but never invents a translation.
nonisolated enum EnglishProductNameResolver {
    static func resolvedName(
        candidates: [String?],
        brand: String?,
        category: String,
        categoryTags: [String]
    ) -> String {
        if let candidate = verifiedName(
            candidates: candidates,
            brand: brand,
            categoryTags: categoryTags
        ) {
            return candidate
        }

        return fallbackName(brand: brand, category: category, categoryTags: categoryTags)
    }

    static func verifiedName(
        candidates: [String?],
        brand: String?,
        categoryTags: [String] = []
    ) -> String? {
        candidates
            .compactMap(clean)
            .first(where: {
                isSafeForEnglishUI($0, brand: brand, categoryTags: categoryTags)
            })
    }

    static func displayName(for product: Product) -> String {
        resolvedName(
            candidates: [product.name],
            brand: product.brand == "Unknown brand" ? nil : product.brand,
            category: product.category,
            categoryTags: product.categoryTags
        )
    }

    private static func isSafeForEnglishUI(
        _ candidate: String,
        brand: String?,
        categoryTags: [String] = []
    ) -> Bool {
        if isBrandOnlyOrBrandDerived(candidate, brand: brand) {
            return true
        }

        // OFF sometimes copies the main product label into
        // `product_name_en`. A short label can fool NaturalLanguage's
        // recognizer, so reject clear grocery-language markers before using
        // that field as English UI copy. This is a safety check, not a
        // translation attempt; the caller still falls back to the trusted
        // English generic/category descriptor.
        let normalizedCandidate = ProductText.normalized(candidate)
        if foreignGroceryMarkers.contains(where: {
            normalizedCandidate.contains(ProductText.normalized($0))
        }) {
            return false
        }

        // Short catalog labels can be too ambiguous for NLLanguageRecognizer.
        // A common failure mode is a foreign compound that ends in the English
        // taxonomy term (for example, "Tomatenketchup"). Treat that as an
        // unverified label so the UI falls back to the trusted English tag.
        if containsEmbeddedCategoryTerm(candidate, categoryTags: categoryTags) {
            return false
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(candidate)
        let hypotheses = recognizer.languageHypotheses(withMaximum: 3)
        let englishScore = hypotheses[.english] ?? 0
        let strongestForeign = hypotheses
            .filter { $0.key != .english }
            .max { $0.value < $1.value }

        guard let strongestForeign else {
            return true
        }

        let foreignDominates = strongestForeign.value > englishScore
        if foreignDominates, strongestForeign.value >= 0.85 {
            return false
        }

        let letterCount = candidate.unicodeScalars.filter(CharacterSet.letters.contains).count
        let lexicalWordCount = candidate.split(whereSeparator: { !$0.isLetter }).count
        let isSubstantivePhrase = lexicalWordCount >= 2 && letterCount >= 8

        // Language recognition is deliberately not a hard gate for short or
        // ambiguous labels such as "Oreo". A phrase with a materially stronger
        // foreign hypothesis is safe to replace with an English fallback.
        return !(isSubstantivePhrase && foreignDominates && strongestForeign.value >= 0.60)
    }

    private static func containsEmbeddedCategoryTerm(
        _ candidate: String,
        categoryTags: [String]
    ) -> Bool {
        let candidateWords = candidate
            .lowercased()
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)

        let categoryTerms = ProductText.orderedStrongCategoryTags(in: categoryTags)
            .filter { $0.hasPrefix("en:") }
            .flatMap { tag in
                tag
                    .split(separator: ":", maxSplits: 1)
                    .last?
                    .split(separator: "-")
                    .map(String.init) ?? []
            }
            .filter { $0.count >= 4 }

        return categoryTerms.contains { categoryTerm in
            candidateWords.contains { word in
                guard word.count > categoryTerm.count else { return false }

                let surroundingText: String
                if word.hasPrefix(categoryTerm) {
                    surroundingText = String(word.dropFirst(categoryTerm.count))
                } else if word.hasSuffix(categoryTerm) {
                    surroundingText = String(word.dropLast(categoryTerm.count))
                } else {
                    return false
                }

                guard surroundingText.count >= 4 else { return false }

                let recognizer = NLLanguageRecognizer()
                recognizer.processString(surroundingText)
                let hypotheses = recognizer.languageHypotheses(withMaximum: 4)
                let englishScore = hypotheses[.english] ?? 0
                guard let strongestForeign = hypotheses
                    .filter({ $0.key != .english })
                    .max(by: { $0.value < $1.value }) else {
                    return false
                }

                return strongestForeign.value >= 0.50
                    && strongestForeign.value >= englishScore + 0.20
            }
        }
    }

    private static func isBrandOnlyOrBrandDerived(_ candidate: String, brand: String?) -> Bool {
        guard let brand = clean(brand) else { return false }

        let normalizedCandidate = ProductText.normalized(candidate)
        guard !normalizedCandidate.isEmpty else { return false }

        // Preserve a pure brand or a separately listed brand alias, but do not
        // let a brand prefix make a foreign product description appear English.
        return brand
            .split(separator: ",")
            .map(String.init)
            .map(ProductText.normalized)
            .contains { !$0.isEmpty && $0 == normalizedCandidate }
    }

    private static let foreignGroceryMarkers = [
        "chocolat noir", "chocolat au", "sans sucre", "sucre", "lait", "farine",
        "tomatenketchup", "tomaten", "würzmittel", "saucen", "haferflocken", "zucker",
        "azúcar", "azucar", "leche", "harina", "açúcar", "acucar", "leite", "farinha",
        "zucchero", "sciroppo", "latte", "lievito", "framboise", "fraise", "ogórki",
        "cukier", "mąka", "mleko", "rajčat", "cukr", "mouka"
    ]

    private static func fallbackName(
        brand: String?,
        category: String,
        categoryTags: [String]
    ) -> String {
        let brand = clean(brand)
        let englishCategory = englishCategoryName(category, categoryTags: categoryTags)

        switch (brand, englishCategory) {
        case let (brand?, category?):
            return "\(brand) \(category)"
        case let (brand?, nil):
            return "\(brand) grocery product"
        case let (nil, category?):
            return category
        case (nil, nil):
            return "Grocery item"
        }
    }

    private static func englishCategoryName(_ category: String, categoryTags: [String]) -> String? {
        if let englishTag = ProductText.orderedStrongCategoryTags(in: categoryTags)
            .last(where: { $0.hasPrefix("en:") }) {
            return categoryName(fromTag: englishTag)
        }

        guard let category = clean(category), isSafeForEnglishUI(category, brand: nil) else {
            return nil
        }
        return category
    }

    private static func categoryName(fromTag tag: String) -> String? {
        let value = tag
            .split(separator: ":", maxSplits: 1)
            .last
            .map(String.init) ?? tag
        let name = value
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .capitalized
        return name.isEmpty ? nil : name
    }

    private static func clean(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}

nonisolated extension Product {
    var displayCategoryName: String {
        if let family = ProductFamily.classify(self) {
            return PicklyCopy.localized(family.displayName)
        }

        let rawCategory = category
            .split(separator: ":", maxSplits: 1)
            .last
            .map(String.init) ?? category
        let cleaned = rawCategory
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? PicklyCopy.localized("Grocery") : PicklyCopy.localized(cleaned.capitalized)
    }
}
