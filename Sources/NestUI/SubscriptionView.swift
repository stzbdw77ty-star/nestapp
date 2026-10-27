import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(SubscriptionStore.self) private var subscription
    @Environment(\.openURL) private var openURL
    private var privacyURL: URL? { configuredURL("NestPrivacyURL") }
    private var termsURL: URL? { configuredURL("NestTermsURL") }
    private var canSell: Bool {
        Bundle.main.object(forInfoDictionaryKey: "NestPurchasesEnabled") as? Bool == true && privacyURL != nil && termsURL != nil
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Label("Nest Plus", systemImage: "leaf.fill").font(.largeTitle.bold())
                Text("A little clarity. More room for your life.").font(.title2)
                Text("Spending insights, flexible goals and thoughtful planning in one place.")
                if subscription.active {
                    Label("Your subscription is active", systemImage: "checkmark.seal.fill").font(.headline)
                } else if let product = subscription.product {
                    Text("\(product.displayPrice) / month").font(.largeTitle.bold())
                    if subscription.eligibleTrial { Text("7 days free, then \(product.displayPrice) each month.").font(.headline) }
                    Text("Renews automatically unless cancelled. Manage or cancel in your App Store subscriptions. Trial availability depends on eligibility.").font(.footnote)
                    Button(subscription.eligibleTrial ? "Start 7-day free trial" : "Subscribe") { Task { await subscription.purchase() } }
                        .buttonStyle(.borderedProminent).disabled(subscription.busy || !canSell)
                } else {
                    Text("Planned subscription: A$10/month, with a 7-day introductory trial for eligible users.")
                    Button("Reload subscription details") { Task { await subscription.load() } }
                }
                if !canSell { Text("Preview build: purchases are disabled while live services and subscription setup are completed. No payment is required to explore sample data.").font(.footnote).foregroundStyle(.secondary) }
                Button("Restore purchases") { Task { await subscription.restore() } }.disabled(subscription.busy)
                Button("Manage App Store subscriptions") { openURL(URL(string: "https://apps.apple.com/account/subscriptions")!) }
                if let privacyURL { Link("Privacy policy", destination: privacyURL) }
                if let termsURL { Link("Terms of use", destination: termsURL) }
                if subscription.busy { ProgressView() }
                if let message = subscription.message { Text(message).font(.footnote) }
            }.padding(24).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }.navigationTitle("Membership")
    }
    private func configuredURL(_ key: String) -> URL? {
        guard let text = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              let url = URL(string: text), url.scheme == "https", url.host != nil else { return nil }
        return url
    }
}
