import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import NestCore

public struct CoachContext: Codable, Sendable {
    public let incomeCents: Int64
    public let spendingCents: Int64
    public let potentialReductionCents: Int64?
    public let unallocatedCents: Int64?
    public let shortfallCents: Int64?
    public let sampleData: Bool
    public init(incomeCents: Int64, spendingCents: Int64, plan: LifestylePlan?, sampleData: Bool) {
        self.incomeCents = incomeCents; self.spendingCents = spendingCents
        potentialReductionCents = plan?.confirmed == true ? plan?.potentialReduction : nil
        unallocatedCents = plan?.confirmed == true ? plan?.availableAfterChanges : nil
        shortfallCents = plan?.confirmed == true ? plan?.shortfall : nil
        self.sampleData = sampleData
    }
}
public struct CoachReply: Codable, Sendable { public let text: String }
public protocol FinanceCoach: Sendable {
    func reply(to question: String, context: CoachContext) async throws -> String
}
public struct LocalCoach: FinanceCoach {
    public init() {}
    public func reply(to question: String, context: CoachContext) async throws -> String {
        let q = question.lowercased()
        if q.contains("inflation") {
            return "Inflation means prices rise over time, so the same amount of money buys less. A long-term goal may need a larger dollar target in the future. Nest’s current investment scenarios show nominal dollars and do not adjust for inflation."
        }
        if q.contains("compound") {
            return "Compounding means returns can themselves earn returns over time. It can also make unpaid debt grow. Nest’s investment illustration compounds monthly using your assumed annual return; real investments don’t deliver a steady return every month."
        }
        if q.contains("emergency") || q.contains("buffer") {
            return "A buffer gives you breathing room for unexpected bills or a change in income. The amount depends on your essentials, income stability and support available. Add a reserve in your lifestyle plan so that money isn’t treated as available for other goals."
        }
        if q.contains("invest") || q.contains("stock") || q.contains("etf") || q.contains("risk") {
            return "Let’s start with the foundations: upcoming bills, debt repayments and a buffer for surprises. Diversification means spreading exposure; it doesn’t remove investment risk. Nest’s scenarios let you explore assumptions, but they don’t select investments or assess suitability. A licensed adviser can help with a personal investment decision."
        }
        if q.contains("debt") || q.contains("loan") || q.contains("interest") {
            return "Interest is the cost of borrowing. Extra repayments can reduce the balance sooner and may reduce total interest. Open Debts & loans to compare timelines using your balance, rate and monthly payment. Check fees and repayment conditions with your lender first."
        }
        if q.contains("save") || q.contains("cut") || q.contains("budget") {
            if let cut = context.potentialReductionCents, let available = context.unallocatedCents {
                if (context.shortfallCents ?? 0) > 0 { return "Your saved scenario still has a monthly gap of \(Money.text(context.shortfallCents!)). Let’s focus on covering commitments before setting money aside. You can revisit the numbers in your lifestyle plan." }
                return "Your saved plan explores cutting \(Money.text(cut)) from flexible spending and leaves \(Money.text(available)) unallocated after your listed commitments. Recheck those amounts before acting; you could direct money to a buffer, a debt or a goal. Protected categories stay untouched."
            }
            return "Let’s protect the things that matter to you first. In Insights, open your lifestyle plan, check your full-month income and costs, and choose the categories you want to keep. We’ll show a transparent budget scenario once you confirm those amounts."
        }
        if q.contains("goal") || q.contains("holiday") {
            return "Give the goal a target amount and date, then add what you’ve already set aside. Nest estimates a monthly saving pace. Keep each dollar assigned to one goal so your plans don’t compete for the same money."
        }
        if q.contains("spend") || q.contains("going") || q.contains("income") {
            return "This month’s recorded income is \(Money.text(context.incomeCents)) and posted spending is \(Money.text(context.spendingCents)). The difference is \(Money.text(context.incomeCents - context.spendingCents)), but that isn’t a bank balance or a safe-to-spend amount. Check the spending chart for category patterns.\(context.sampleData ? " These figures are sample data." : "")"
        }
        return "I can help with recorded spending, saving goals, budgeting, debt interest and basic investing concepts. Try ‘How is my spending going?’ or ‘How could I save more?’ This offline guide uses prepared explanations; it isn’t a live AI model."
    }
}
public struct LiveCoach: FinanceCoach {
    public let api: NestAPI
    public init(api: NestAPI) { self.api = api }
    public func reply(to question: String, context: CoachContext) async throws -> String {
        struct Request: Encodable { let question: String; let context: CoachContext }
        let body = try JSONEncoder().encode(Request(question: question, context: context))
        let reply = try await api.request("v1/coach", method: "POST", body: body, as: CoachReply.self)
        guard !reply.text.isEmpty else { throw ServiceError.invalidData }; return reply.text
    }
}
