import SwiftUI
import Foundation

struct ContentView: View {
    @StateObject private var productCatalog: ProductCatalogStore
    @StateObject private var savedStore = SavedProductsStore()
    @StateObject private var authStore: AuthStore
    @StateObject private var preferencesStore = PreferencesStore()
    @StateObject private var onboardingStore: OnboardingStore
    @EnvironmentObject private var languageStore: PicklyLanguageStore
    @State private var selectedTab = PicklyTab.search

    init(
        catalog: ProductCatalogStore? = nil,
        onboardingStore: OnboardingStore? = nil,
        authStore: AuthStore? = nil
    ) {
        _productCatalog = StateObject(
            wrappedValue: catalog ?? ProductCatalogStore()
        )
        _onboardingStore = StateObject(
            wrappedValue: onboardingStore ?? OnboardingStore()
        )
        _authStore = StateObject(wrappedValue: authStore ?? AuthStore())

#if DEBUG
        if let argumentIndex = ProcessInfo.processInfo.arguments.firstIndex(of: "-pickly-tab"),
           let rawTab = ProcessInfo.processInfo.arguments.dropFirst(argumentIndex + 1).first,
           let tab = PicklyTab(rawValue: rawTab) {
            _selectedTab = State(initialValue: tab)
        }
#endif
    }

    var body: some View {
        Group {
            if onboardingStore.hasCompletedOnboarding {
                mainTabView
                    .transition(.opacity)
            } else {
                OnboardingView(
                    onComplete: onboardingStore.complete,
                    preferences: $preferencesStore.preferences,
                    authStore: authStore
                )
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: onboardingStore.hasCompletedOnboarding)
        .task {
            await productCatalog.loadInitial()
            savedStore.refreshSnapshots(from: productCatalog.products)
        }
    }

    private var mainTabView: some View {
        TabView(selection: selectedTabBinding) {
            NavigationStack {
                SearchView(
                    catalog: productCatalog,
                    savedStore: savedStore,
                    authStore: authStore,
                    preferences: preferencesStore.preferences,
                    onOpenPreferences: openProfile,
                    onScanAnotherProduct: openScanner
                )
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
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
                Label("Scan", picklyIcon: "barcode.viewfinder", iconSize: 22)
            }
            .tag(PicklyTab.scan)

            NavigationStack {
                SavedView(
                    productService: productCatalog,
                    savedStore: savedStore,
                    preferences: preferencesStore.preferences,
                    onScanAnotherProduct: openScanner
                )
            }
            .tabItem {
                Label("Saved", picklyIcon: "bookmark", iconSize: 22)
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
                Label("Profile", picklyIcon: "person.crop.circle", iconSize: 22)
            }
            .tag(PicklyTab.profile)
        }
        .tint(PicklyColor.primary)
        .toolbarBackground(PicklyColor.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }

    private var selectedTabBinding: Binding<PicklyTab> {
        Binding(
            get: { selectedTab },
            set: { selectedTab = $0 }
        )
    }

    private func openProfile() {
        selectedTab = .profile
    }

    private func openScanner() {
        selectedTab = .scan
    }
}

private enum PicklyTab: String, Hashable {
    case search
    case scan
    case saved
    case profile
}

#Preview {
    ContentView(catalog: .preview)
        .environmentObject(SubscriptionStore(loadProducts: false))
        .environmentObject(PicklyLanguageStore())
}
