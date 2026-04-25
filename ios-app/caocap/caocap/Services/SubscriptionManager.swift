import Foundation
import StoreKit
import Observation

@MainActor
@Observable
public class SubscriptionManager {
    public static let shared = SubscriptionManager()
    
    public private(set) var products: [Product] = []
    public private(set) var purchasedProductIDs = Set<String>()
    public private(set) var isLoading = false
    
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
    
    init() {
        // Start listening for transactions
        updatesCanceller.task = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(transactionResult: result)
            }
        }
    }
    
    public func fetchProducts() async {
        guard products.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            products = try await Product.products(for: productIDs)
        } catch {
            print("Failed to fetch products: \(error)")
        }
    }
    
    public func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()
            return transaction
        case .userCancelled, .pending:
            return nil
        @unknown default:
            return nil
        }
    }
    
    public func updatePurchasedProducts() async {
        var newPurchasedProductIDs = Set<String>()
        
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            
            if transaction.revocationDate == nil {
                newPurchasedProductIDs.insert(transaction.productID)
            }
        }
        
        self.purchasedProductIDs = newPurchasedProductIDs
    }
    
    public func restorePurchases() async throws {
        try await AppStore.sync()
        await updatePurchasedProducts()
    }
    
    private func handle(transactionResult: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = transactionResult else { return }
        
        if transaction.revocationDate == nil {
            purchasedProductIDs.insert(transaction.productID)
        } else {
            purchasedProductIDs.remove(transaction.productID)
        }
        
        await transaction.finish()
    }
    
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
