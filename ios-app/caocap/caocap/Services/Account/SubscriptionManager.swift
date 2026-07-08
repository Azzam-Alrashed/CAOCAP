import Foundation
import StoreKit
import Observation
import OSLog

/// Owns StoreKit product loading, purchase state, restoration, and transaction
/// updates for CAOCAP Pro.
@MainActor
@Observable
public class SubscriptionManager {
    public static let shared = SubscriptionManager()
    private let logger = Logger(subsystem: "CAOCAP", category: "SubscriptionManager")
    
    public private(set) var products: [Product] = []
    public private(set) var purchasedProductIDs = Set<String>()
    public private(set) var isLoading = false
    /// `false` until the first StoreKit entitlement refresh completes.
    public private(set) var entitlementsResolved = false
    public private(set) var isRefreshingEntitlements = false
    
    public var isSubscribed: Bool {
        !purchasedProductIDs.isEmpty
    }
    
    private let productIDs = [
        "CAOCAP_Pro_Monthly",
        "CAOCAP_Pro_Yearly"
    ]
    
    private final class TaskCanceller {
        var task: Task<Void, Never>?
        deinit {
            task?.cancel()
        }
    }
    
    private let updatesCanceller = TaskCanceller()
    private var refreshEntitlementsTask: Task<Void, Never>?

    /// Test hook that bypasses StoreKit when set.
    internal var testing_updateHandler: (() async -> Void)?
    internal private(set) var testing_updateInvocationCount = 0

    init() {
        startBackgroundTasks()
    }

    internal init(testing_updateHandler: @escaping () async -> Void) {
        self.testing_updateHandler = testing_updateHandler
    }

    private func startBackgroundTasks() {
        Task { [weak self] in
            await self?.refreshEntitlements()
        }

        // Keep entitlement state fresh for renewals, refunds, upgrades, and
        // purchases completed outside the current paywall session.
        updatesCanceller.task = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(transactionResult: result)
            }
        }
    }
    
    /// Loads StoreKit products once per manager lifetime. The paywall can show
    /// fallback prices while this request is pending or unavailable.
    public func fetchProducts() async {
        guard products.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            products = try await Product.products(for: productIDs)
        } catch {
            logger.error("Failed to fetch products: \(error)")
        }
    }
    
    /// Starts a StoreKit purchase and returns a verified transaction only when
    /// access should be granted immediately.
    public func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await refreshEntitlements()
            await transaction.finish()
            return transaction
        case .userCancelled, .pending:
            return nil
        @unknown default:
            return nil
        }
    }
    
    /// Refreshes entitlements from StoreKit, coalescing concurrent callers.
    public func refreshEntitlements() async {
        if let refreshEntitlementsTask {
            await refreshEntitlementsTask.value
            return
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            self.isRefreshingEntitlements = true
            defer {
                self.isRefreshingEntitlements = false
                self.entitlementsResolved = true
            }
            await self.updatePurchasedProducts()
        }
        refreshEntitlementsTask = task
        await task.value
        refreshEntitlementsTask = nil
    }

    /// Rebuilds the current entitlement set from StoreKit's verified active
    /// transactions, ignoring revoked purchases.
    public func updatePurchasedProducts() async {
        testing_updateInvocationCount += 1

        if let testing_updateHandler {
            await testing_updateHandler()
            return
        }

        var newPurchasedProductIDs = Set<String>()
        
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            
            if transaction.revocationDate == nil {
                newPurchasedProductIDs.insert(transaction.productID)
            }
        }
        
        self.purchasedProductIDs = newPurchasedProductIDs
    }
    
    /// Triggers App Store account sync, then refreshes local entitlement state.
    public func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }
    
    /// Handles transaction updates delivered after initial purchase, including
    /// renewals and revocations.
    private func handle(transactionResult: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = transactionResult else { return }
        
        if transaction.revocationDate == nil {
            purchasedProductIDs.insert(transaction.productID)
        } else {
            purchasedProductIDs.remove(transaction.productID)
        }
        entitlementsResolved = true
        
        await transaction.finish()
    }
    
    /// StoreKit verification is the trust boundary for granting Pro access.
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

public enum StoreError: Error {
    case failedVerification
}
