import SwiftUI

struct ContentView: View {
    @StateObject private var savedStore = SavedProductsStore()

    private let productService = MockProductService()
    private let preferences = UserPreferences.prototype

    var body: some View {
        TabView {
            NavigationStack {
                SearchView(
                    productService: productService,
                    savedStore: savedStore,
                    preferences: preferences
                )
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }

            NavigationStack {
                SavedView(
                    productService: productService,
                    savedStore: savedStore,
                    preferences: preferences
                )
            }
            .tabItem {
                Label("Saved", systemImage: "bookmark")
            }
        }
        .tint(.green)
    }
}

#Preview {
    ContentView()
}
