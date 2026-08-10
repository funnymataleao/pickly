import Combine
import Foundation
import StoreKit

/// Owns the StoreKit entitlement used by Pickly's optional Plus features.
///
/// Product availability is deliberately treated as a runtime concern. The app
/// remains fully useful when App Store Connect has not returned products yet,
/// which keeps the free scanning flow usable in development and offline states.
@MainActor
final class SubscriptionStore: ObservableObject {
    enum Plan: String, CaseIterable, Identifiable {
        case monthly
        case annual

        var id: String { rawValue }

        var productID: String {
            switch self {
            case .monthly:
                return "com.pickly.plus.monthly"
            case .annual:
                return "com.pickly.plus.annual"
            }
        }

        var title: String {
            switch self {
            case .monthly:
                return "Monthly"
            case .annual:
                return "Annual"
            }
        }
    }

    enum StoreError: LocalizedError {
        case unavailable
        case verificationFailed

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "Pickly Plus is not available right now. Please try again later."
            case .verificationFailed:
                return "We couldn't verify that purchase. Please try again."
            }
        }
    }

    static let productIDs = Plan.allCases.map(\.productID)

    @Published private(set) var products: [StoreKit.Product] = []
    @Published private(set) var isPlus = false
    @Published private(set) var isLoading = false
    @Published private(set) var isPurchasing = false
    @Published var statusMessage: String?

    private let shouldLoadProducts: Bool
    private var updatesTask: Task<Void, Never>?
    private var hasStartedLoading = false

    init(loadProducts: Bool = true) {
        self.shouldLoadProducts = loadProducts
    }

    deinit {
        updatesTask?.cancel()
    }

    var hasProducts: Bool {
        !products.isEmpty
    }

    /// Starts transaction observation and restores the current entitlement
    /// before the paywall is opened. Paid access must not depend on visiting
    /// the subscription screen first.
    func start() async {
        guard shouldLoadProducts, !hasStartedLoading else { return }

        hasStartedLoading = true
        updatesTask = Task { [weak self] in
            await self?.observeTransactionUpdates()
        }
        await refreshEntitlement()
    }

    func refresh() async {
        guard shouldLoadProducts else {
            return
        }

        await start()

        isLoading = true
        statusMessage = nil
        defer { isLoading = false }

        do {
            let loadedProducts = try await StoreKit.Product.products(for: Self.productIDs)
            products = loadedProducts.sorted { lhs, rhs in
                Self.productIDs.firstIndex(of: lhs.id) ?? .max
                    < Self.productIDs.firstIndex(of: rhs.id) ?? .max
            }
            await refreshEntitlement()
        } catch {
            products = []
            statusMessage = StoreError.unavailable.errorDescription
            await refreshEntitlement()
        }
    }

    func purchase(_ plan: Plan) async -> Bool {
        guard let product = products.first(where: { $0.id == plan.productID }) else {
            statusMessage = StoreError.unavailable.errorDescription
            return false
        }

        guard !isPurchasing else {
            return false
        }

        isPurchasing = true
        statusMessage = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try verifiedTransaction(from: verification)
                await transaction.finish()
                await refreshEntitlement()
                return isPlus
            case .userCancelled:
                return false
            case .pending:
                statusMessage = "Your purchase is pending approval."
                return false
            @unknown default:
                statusMessage = StoreError.unavailable.errorDescription
                return false
            }
        } catch let error as StoreError {
            statusMessage = error.errorDescription
            return false
        } catch {
            statusMessage = "The purchase couldn't be completed. Please try again."
            return false
        }
    }

    func restorePurchases() async {
        guard !isPurchasing else {
            return
        }

        isPurchasing = true
        statusMessage = nil
        defer { isPurchasing = false }

        do {
            try await AppStore.sync()
            await refreshEntitlement()
            statusMessage = isPlus
                ? "Pickly Plus is active on this device."
                : "No active Pickly Plus subscription was found."
        } catch {
            statusMessage = "We couldn't restore purchases. Check your connection and try again."
        }
    }

    private func observeTransactionUpdates() async {
        for await verificationResult in StoreKit.Transaction.updates {
            guard case .verified(let transaction) = verificationResult else {
                continue
            }

            await transaction.finish()
            await refreshEntitlement()
        }
    }

    private func refreshEntitlement() async {
        var active = false

        for await verificationResult in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = verificationResult else {
                continue
            }

            guard
                Self.productIDs.contains(transaction.productID),
                transaction.revocationDate == nil
            else {
                continue
            }

            if let expirationDate = transaction.expirationDate,
               expirationDate <= .now {
                continue
            }

            active = true
            break
        }

        isPlus = active
    }

    private func verifiedTransaction(
        from result: VerificationResult<StoreKit.Transaction>
    ) throws -> StoreKit.Transaction {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified:
            throw StoreError.verificationFailed
        }
    }
}
