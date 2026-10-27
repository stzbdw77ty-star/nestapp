import Foundation

public enum GoalKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case holiday = "Holiday", independence = "Financial independence", purchase = "Big purchase", other = "Something else"
    public var id: String { rawValue }
}
public struct SavingsGoal: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var kind: GoalKind
    public var target: Int64
    public var saved: Int64
    public var deadline: Date
    public init(id: UUID = UUID(), name: String, kind: GoalKind, target: Int64, saved: Int64, deadline: Date) {
        self.id = id; self.name = name; self.kind = kind; self.target = target; self.saved = saved; self.deadline = deadline
    }
    public var remaining: Int64 { max(0, target - saved) }
    public var progress: Double { target > 0 ? min(1, Double(saved) / Double(target)) : 0 }
    public func monthlyPace(now: Date = .now, calendar: Calendar = .current) -> Int64? {
        if remaining == 0 { return 0 }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: deadline)).day ?? 0
        guard days > 0 else { return nil }
        return Int64(ceil(Double(remaining) / Double(days) * 30.4375))
    }
}
public struct Debt: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var balance: Int64
    public var annualRatePercent: Double
    public var payment: Int64
    public var extra: Int64
    public init(id: UUID = UUID(), name: String, balance: Int64, annualRatePercent: Double, payment: Int64, extra: Int64) {
        self.id = id; self.name = name; self.balance = balance; self.annualRatePercent = annualRatePercent; self.payment = payment; self.extra = extra
    }
}
public struct DebtPoint: Identifiable, Sendable {
    public var id: Int { month }
    public let month: Int
    public let balance: Int64
}
public struct DebtSchedule: Sendable {
    public let months: Int
    public let interest: Int64
    public let points: [DebtPoint]
}
public enum Planning {
    public static func payoff(_ debt: Debt, includeExtra: Bool = true) -> DebtSchedule? {
        guard debt.balance >= 0, debt.payment >= 0, debt.extra >= 0,
              debt.annualRatePercent.isFinite, (0...100).contains(debt.annualRatePercent) else { return nil }
        if debt.balance == 0 { return DebtSchedule(months: 0, interest: 0, points: [DebtPoint(month: 0, balance: 0)]) }
        let payment = debt.payment + (includeExtra ? debt.extra : 0)
        guard payment > 0 else { return nil }
        var balance = debt.balance
        var totalInterest: Int64 = 0
        var points = [DebtPoint(month: 0, balance: balance)]
        for month in 1...600 {
            var raw = Decimal(balance) * Decimal(debt.annualRatePercent) / 1200
            var rounded = Decimal()
            NSDecimalRound(&rounded, &raw, 0, .plain)
            let interest = NSDecimalNumber(decimal: rounded).int64Value
            guard payment > interest else { return nil }
            balance = max(0, balance + interest - payment)
            totalInterest += interest
            points.append(DebtPoint(month: month, balance: balance))
            if balance == 0 { return DebtSchedule(months: month, interest: totalInterest, points: points) }
        }
        return nil
    }

    public static func independenceTarget(annualSpending: Int64, withdrawalPercent: Double) -> Int64? {
        guard annualSpending > 0, withdrawalPercent.isFinite, (1...10).contains(withdrawalPercent) else { return nil }
        return Int64(ceil(Double(annualSpending) * 100 / withdrawalPercent))
    }
    /// Illustrative end-of-month contributions, constant nominal return; no tax/fees/inflation.
    public static func futureValue(monthly: Int64, years: Int, annualPercent: Double) -> Int64? {
        guard monthly >= 0, (1...50).contains(years), annualPercent.isFinite, (-50...50).contains(annualPercent) else { return nil }
        let rate = pow(1 + annualPercent / 100, 1.0 / 12) - 1
        var value = 0.0
        for _ in 0..<(years * 12) { value = value * (1 + rate) + Double(monthly) }
        guard value.isFinite, value <= Double(Int64.max / 2) else { return nil }
        return Int64(value.rounded())
    }
}

public struct LifestylePlan: Codable, Equatable, Sendable {
    public var income: Int64 = 0
    public var monthlySpending: Int64 = 0
    public var flexibleSpending: Int64 = 0
    public var reductionPercent: Double = 10
    public var reserve: Int64 = 0
    public var otherCommitments: Int64 = 0
    public var riskPreference = "Balanced"
    public var protectedCategories: [UUID] = []
    public var confirmed = false
    public init() {}
    public var potentialReduction: Int64 {
        Int64((Double(min(max(0, flexibleSpending), max(0, monthlySpending))) * min(30, max(0, reductionPercent)) / 100).rounded(.down))
    }
    public var baselineSurplus: Int64 { income - monthlySpending - reserve - otherCommitments }
    public var availableAfterChanges: Int64 { max(0, baselineSurplus + potentialReduction) }
    public var shortfall: Int64 { max(0, -(baselineSurplus + potentialReduction)) }
}

public struct PlanningSnapshot: Codable, Equatable, Sendable {
    public var goals: [SavingsGoal] = []
    public var debts: [Debt] = []
    public var lifestyle = LifestylePlan()
    public var books = BookkeepingSnapshot()
    public init() {}
    private enum CodingKeys: String, CodingKey { case goals, debts, lifestyle, books }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        goals = try values.decodeIfPresent([SavingsGoal].self, forKey: .goals) ?? []
        debts = try values.decodeIfPresent([Debt].self, forKey: .debts) ?? []
        lifestyle = try values.decodeIfPresent(LifestylePlan.self, forKey: .lifestyle) ?? LifestylePlan()
        books = try values.decodeIfPresent(BookkeepingSnapshot.self, forKey: .books) ?? BookkeepingSnapshot()
    }
}

public struct MonthTotal: Identifiable, Sendable {
    public var id: Date { month }
    public let month: Date
    public let income: Int64
    public let spending: Int64
}
public enum Insights {
    public static func months(_ entries: [Entry], now: Date = .now, calendar: Calendar = .current) -> [MonthTotal] {
        (0..<6).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .month, value: -offset, to: now),
                  let start = calendar.dateInterval(of: .month, for: date)?.start else { return nil }
            let rows = Ledger.entries(entries, month: start, calendar: calendar)
            return MonthTotal(month: start, income: Ledger.total(rows, kind: .income), spending: Ledger.total(rows, kind: .expense))
        }
    }
    public static func commentary(_ entries: [Entry], categories: [Category], now: Date = .now) -> String {
        let rows = Ledger.entries(entries, month: now)
        guard !rows.isEmpty else { return "A fresh month. Add a few transactions and we’ll help you spot the patterns." }
        let spending = Ledger.total(rows, kind: .expense)
        guard let biggest = Ledger.spending(rows, categories: categories).first else {
            return "No posted expenses this month yet. Pending payments will join the totals once they settle."
        }
        return "You’ve recorded \(Money.text(spending)) in spending this month. \(biggest.category.name) is the largest category at \(Money.text(biggest.cents)). Does that fit the month you had in mind?"
    }
}
