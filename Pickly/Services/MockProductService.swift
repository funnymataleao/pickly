import Foundation

struct MockProductService {
    let products: [Product] = [
        Product(
            id: "greek-yogurt",
            barcode: "000111222333",
            name: "Plain Greek Yogurt",
            brand: "Field & Spoon",
            category: "Dairy",
            imageName: "cup.and.saucer.fill",
            ingredients: ["Cultured milk", "Live active cultures"],
            nutritionSummary: "0g added sugar, 70mg sodium, 16g protein",
            score: 92,
            summary: "A simple option with high protein and no added sugar.",
            reasons: ["No added sugar", "Short ingredient list", "Higher protein than many similar options"],
            warnings: ["Contains dairy"],
            positives: ["High protein", "Short ingredient list"],
            forYouNotes: ["Better option if you're limiting sugar"],
            alternativeIDs: [],
            confidence: "High"
        ),
        Product(
            id: "honey-crunch-cereal",
            barcode: "111222333444",
            name: "Honey Crunch Cereal",
            brand: "Morning Basket",
            category: "Breakfast",
            imageName: "takeoutbag.and.cup.and.straw.fill",
            ingredients: ["Whole grain oats", "Sugar", "Honey", "Rice flour", "Canola oil", "Salt", "Natural flavor"],
            nutritionSummary: "11g added sugar, 160mg sodium, 3g fiber",
            score: 58,
            summary: "Better as an occasional option because it has more added sugar than similar cereals.",
            reasons: ["Contains whole grain oats", "Has some fiber"],
            warnings: ["Contains more added sugar than similar products", "Ingredient list is longer than simpler cereals"],
            positives: ["Whole grain first ingredient"],
            forYouNotes: ["May not be the best choice if you're reducing sugar"],
            alternativeIDs: ["simple-oat-cereal", "protein-granola"],
            confidence: "Medium"
        ),
        Product(
            id: "simple-oat-cereal",
            barcode: "222333444555",
            name: "Simple Oat Cereal",
            brand: "Grain House",
            category: "Breakfast",
            imageName: "leaf.fill",
            ingredients: ["Whole grain oats", "Sea salt"],
            nutritionSummary: "1g added sugar, 90mg sodium, 5g fiber",
            score: 88,
            summary: "A calmer breakfast choice with very little added sugar and a short ingredient list.",
            reasons: ["Very low added sugar", "Short ingredient list", "Good source of fiber"],
            warnings: ["Flavor is less sweet than many cereals"],
            positives: ["Less added sugar", "Shorter ingredient list"],
            forYouNotes: ["Better option if you're limiting sugar"],
            alternativeIDs: ["protein-granola"],
            confidence: "High"
        ),
        Product(
            id: "protein-granola",
            barcode: "333444555666",
            name: "Protein Granola",
            brand: "Trail Table",
            category: "Breakfast",
            imageName: "bolt.heart.fill",
            ingredients: ["Oats", "Almonds", "Pea protein", "Chicory fiber", "Maple syrup", "Sea salt"],
            nutritionSummary: "4g added sugar, 75mg sodium, 10g protein",
            score: 79,
            summary: "A balanced choice with more protein and moderate added sugar.",
            reasons: ["Higher protein", "Moderate added sugar", "Includes fiber"],
            warnings: ["Contains almonds"],
            positives: ["Higher protein", "Lower sodium"],
            forYouNotes: ["A reasonable option if you want a more filling breakfast"],
            alternativeIDs: ["simple-oat-cereal"],
            confidence: "Medium"
        ),
        Product(
            id: "tomato-basil-soup",
            barcode: "444555666777",
            name: "Tomato Basil Soup",
            brand: "Pantry Lane",
            category: "Soup",
            imageName: "fork.knife.circle.fill",
            ingredients: ["Tomatoes", "Water", "Cream", "Onion", "Basil", "Salt", "Sugar", "Garlic"],
            nutritionSummary: "3g added sugar, 680mg sodium, 3g saturated fat",
            score: 63,
            summary: "A convenient soup, though sodium is higher than many everyday options.",
            reasons: ["Recognizable ingredient list", "Tomatoes are the first ingredient"],
            warnings: ["Higher sodium than many similar soups", "Contains cream"],
            positives: ["Vegetable-forward ingredient list"],
            forYouNotes: ["You might prefer a lower sodium option below"],
            alternativeIDs: ["low-sodium-lentil-soup"],
            confidence: "Medium"
        ),
        Product(
            id: "low-sodium-lentil-soup",
            barcode: "555666777888",
            name: "Low Sodium Lentil Soup",
            brand: "Pantry Lane",
            category: "Soup",
            imageName: "carrot.fill",
            ingredients: ["Water", "Lentils", "Tomatoes", "Carrots", "Celery", "Onion", "Olive oil", "Spices"],
            nutritionSummary: "0g added sugar, 320mg sodium, 8g protein",
            score: 84,
            summary: "A more balanced soup with lower sodium and plant-based protein.",
            reasons: ["Lower sodium", "No added sugar", "Good source of plant-based protein"],
            warnings: ["Contains legumes"],
            positives: ["Lower sodium", "Higher protein"],
            forYouNotes: ["May be a better fit if you want a lighter everyday soup"],
            alternativeIDs: [],
            confidence: "High"
        )
    ]

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
}
