//
//  PicklyApp.swift
//  Pickly
//
//  Created by mataleao on 27/04/2026.
//

import SwiftUI

@main
struct PicklyApp: App {
    @StateObject private var subscriptionStore = SubscriptionStore()
    @StateObject private var authStore = AuthStore()

    var body: some Scene {
        WindowGroup {
            ContentView(authStore: authStore)
                .environmentObject(subscriptionStore)
                .onOpenURL { url in
                    Task {
                        if !(await authStore.handleIncomingURL(url)) {
                            GoogleSignInProvider.handle(url: url)
                        }
                    }
                }
                .task {
                    await subscriptionStore.start()
                }
        }
    }
}
