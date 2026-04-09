import StoreKit
import Combine

// MARK: - Product IDs

enum ProProduct: String, CaseIterable {
    case monthly = "com.mlexplorer.pro.monthly"
    case annual  = "com.mlexplorer.pro.annual"
}

// MARK: - SubscriptionService

@MainActor
final class SubscriptionService: ObservableObject {

    static let shared = SubscriptionService()

    /// Set this in tests / SwiftUI previews to override real entitlement check.
    /// Launch arg:  -MLExplorerForcePro YES   → always pro
    ///              -MLExplorerForcePro NO    → always free
    @Published private(set) var isPro: Bool = false

    #if DEBUG
    func overridePro(_ value: Bool) { isPro = value }
    #endif
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var purchaseError: String? = nil

    private var updateTask: Task<Void, Never>? = nil

    private init() {
        updateTask = listenForTransactions()
        #if DEBUG
        // Support launch-argument overrides for UI testing:
        // -MLExplorerForcePro YES  →  simulate pro subscriber
        // -MLExplorerForcePro NO   →  simulate free user
        if let raw = ProcessInfo.processInfo.environment["MLExplorerForcePro"] {
            isPro = (raw == "YES")
            return   // skip StoreKit entirely
        }
        #endif
        Task { await refresh() }
    }

    deinit { updateTask?.cancel() }

    // MARK: - Public

    func purchase(_ product: Product) async {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let tx = try checkVerified(verification)
                await tx.finish()
                await updateStatus()
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        try? await AppStore.sync()
        await updateStatus()
    }

    // MARK: - Private

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let fetched = try await Product.products(for: ProProduct.allCases.map(\.rawValue))
            // monthly first, then annual
            products = fetched.sorted { a, b in
                let order: [String] = [ProProduct.monthly.rawValue, ProProduct.annual.rawValue]
                return (order.firstIndex(of: a.id) ?? 0) < (order.firstIndex(of: b.id) ?? 0)
            }
        } catch {
            // Products not available (simulator / no StoreKit config) — keep empty
        }
        await updateStatus()
    }

    private func updateStatus() async {
        for await result in Transaction.currentEntitlements {
            guard let tx = try? checkVerified(result) else { continue }
            if ProProduct(rawValue: tx.productID) != nil {
                isPro = true
                return
            }
        }
        isPro = false
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                guard let tx = try? checkVerified(result) else { continue }
                await updateStatus()
                await tx.finish()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreError.failedVerification
        case .verified(let value): return value
        }
    }
}

enum StoreError: Error {
    case failedVerification
}

// MARK: - Convenience helpers on Product

extension Product {
    var isMonthly: Bool { id == ProProduct.monthly.rawValue }
    var isAnnual:  Bool { id == ProProduct.annual.rawValue  }

    /// Per-month price string for annual (e.g. "$0.83/mo")
    var annualPerMonthString: String? {
        guard isAnnual else { return nil }
        let perMonth = price / 12
        let fmt = priceFormatStyle
        return "\(fmt.format(perMonth))/mo"
    }

    /// Savings vs monthly (e.g. "Save 72%")
    func savingsLabel(monthly: Product) -> String {
        let monthlyAnnual = monthly.price * 12
        guard monthlyAnnual > 0 else { return "" }
        let saving = (monthlyAnnual - price) / monthlyAnnual * 100
        return "Save \(Int(truncating: saving as NSDecimalNumber))%"
    }
}
