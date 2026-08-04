import SwiftUI

struct ContentView: View {
    @StateObject private var productCatalog: ProductCatalogStore
    @StateObject private var savedStore = SavedProductsStore()
    @StateObject private var authStore = AuthStore()
    @StateObject private var preferencesStore = PreferencesStore()
    @State private var selectedTab = PicklyTab.search

    init(catalog: ProductCatalogStore? = nil) {
        _productCatalog = StateObject(
            wrappedValue: catalog ?? ProductCatalogStore()
        )
    }

    var body: some View {
        TabView(selection: selectedTabBinding) {
            NavigationStack {
                SearchView(
                    catalog: productCatalog,
                    savedStore: savedStore,
                    preferences: preferencesStore.preferences,
                    onOpenPreferences: openProfile
                )
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            .tag(PicklyTab.search)

            NavigationStack {
                ScanView(
                    productLookupService: productCatalog,
                    productService: productCatalog,
                    savedStore: savedStore,
                    preferences: preferencesStore.preferences,
                    isTabActive: selectedTab == .scan
                )
            }
            .tabItem {
                Label("Scan", systemImage: "barcode.viewfinder")
            }
            .tag(PicklyTab.scan)

            NavigationStack {
                SavedView(
                    productService: productCatalog,
                    savedStore: savedStore,
                    preferences: preferencesStore.preferences
                )
            }
            .tabItem {
                Label("Saved", systemImage: "bookmark")
            }
            .tag(PicklyTab.saved)

            NavigationStack {
                ProfileView(
                    preferences: $preferencesStore.preferences,
                    savedStore: savedStore,
                    authStore: authStore,
                    onAccountDeleted: {
                        savedStore.clearLocalData()
                        preferencesStore.reset()
                    }
                )
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle")
            }
            .tag(PicklyTab.profile)
        }
        .tint(PicklyColor.primary)
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: selectedTab)
        .task {
            await productCatalog.loadInitial()
        }
    }

    private var selectedTabBinding: Binding<PicklyTab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                    selectedTab = newValue
                }
            }
        )
    }

    private func openProfile() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            selectedTab = .profile
        }
    }
}

private enum PicklyTab: Hashable {
    case search
    case scan
    case saved
    case profile
}

#Preview {
    ContentView(catalog: .preview)
}
