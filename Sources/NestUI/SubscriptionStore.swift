import Foundation
import Observation
import StoreKit

@MainActor @Observable final class SubscriptionStore {
    static let productID = "com.nest.monthly"
    private(set) var product: Product?
    private(set) var active = false
    private(set) var eligibleTrial = false
    private(set) var busy = false
    var message: String?
    private var updates: Task<Void, Never>?
    func start() async {
        if updates == nil {
            updates = Task { [weak self] in
                for await result in StoreKit.Transaction.updates {
                    guard !Task.isCancelled else { break }
                    guard case .verified(let transaction) = result,
                          transaction.productID == Self.productID else { continue }
                    await self?.refreshEntitlement(); await transaction.finish()
                }
            }
        }
        await load()
    }
    func load() async {
        await refreshEntitlement()
        do {
            product = try await Product.products(for: [Self.productID]).first
            if let product, product.subscription?.subscriptionPeriod.unit != .month || product.subscription?.subscriptionPeriod.value != 1 {
                self.product = nil
            }
            if let subscription = product?.subscription, let offer = subscription.introductoryOffer {
                let sevenDays = (offer.period.unit == .day && offer.period.value == 7) || (offer.period.unit == .week && offer.period.value == 1)
                let eligible = await subscription.isEligibleForIntroOffer
                eligibleTrial = offer.paymentMode == .freeTrial && sevenDays && eligible
            } else { eligibleTrial = false }
            await refreshEntitlement()
            if product == nil { message = "Subscriptions aren’t available in this build yet. The sample workspace is still yours to explore." }
        } catch { message = "Couldn’t load subscription details. Please try again." }
    }
    func purchase() async {
        guard !busy, let product else { return }
        busy = true; message = nil; defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result, transaction.productID == Self.productID else {
                    message = "We couldn’t verify this purchase. Please restore purchases or try again."; return
                }
                await refreshEntitlement(); await transaction.finish(); await load()
                message = active ? "You’re all set. Welcome to Nest Plus." : "Your purchase is being checked. Try Restore purchases if needed."
            case .pending: message = "Your purchase is awaiting approval. Access will update when it is confirmed."
            case .userCancelled: break
            @unknown default: message = "The purchase wasn’t completed. Please try again."
            }
        } catch { message = "The purchase couldn’t be completed. Please try again." }
    }
    func restore() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do { try await AppStore.sync(); await refreshEntitlement(); message = active ? "Your subscription is restored." : "No active subscription was found." }
        catch { message = "Couldn’t restore purchases. Please try again." }
    }
    private func refreshEntitlement() async {
        var entitled = false
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID, transaction.revocationDate == nil, !transaction.isUpgraded { entitled = true }
        }
        active = entitled
    }
}
