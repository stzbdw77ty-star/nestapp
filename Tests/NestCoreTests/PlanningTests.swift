import Testing
import Foundation
@testable import NestCore

@Test func goalPaceHandlesCompletionAndOverdueDates() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    var goal = SavingsGoal(name: "Holiday", kind: .holiday, target: 120000, saved: 0, deadline: now.addingTimeInterval(365 * 86400))
    #expect(goal.monthlyPace(now: now)! >= 10000)
    goal.deadline = now.addingTimeInterval(-86400)
    #expect(goal.monthlyPace(now: now) == nil)
    goal.saved = 120000
    #expect(goal.monthlyPace(now: now) == 0)
    #expect(goal.progress == 1)
}
@Test func debtAmortisationAndExtraPayments() {
    let debt = Debt(name: "Loan", balance: 1_000_000, annualRatePercent: 12, payment: 30000, extra: 10000)
    let base = Planning.payoff(debt, includeExtra: false)!
    let extra = Planning.payoff(debt)!
    #expect(extra.months < base.months)
    #expect(extra.interest < base.interest)
    #expect(extra.points.last?.balance == 0)
    #expect(extra.points.allSatisfy { $0.balance >= 0 })
}
@Test func debtEdgeCases() {
    let zeroRate = Debt(name: "Loan", balance: 100000, annualRatePercent: 0, payment: 25000, extra: 0)
    #expect(Planning.payoff(zeroRate)?.months == 4)
    #expect(Planning.payoff(zeroRate)?.interest == 0)
    let growing = Debt(name: "Card", balance: 100000, annualRatePercent: 24, payment: 1000, extra: 0)
    #expect(Planning.payoff(growing) == nil)
    let paid = Debt(name: "Done", balance: 0, annualRatePercent: 5, payment: 1000, extra: 0)
    #expect(Planning.payoff(paid)?.months == 0)
}
@Test func lifestyleReservesAndShortfallsComeFirst() {
    var plan = LifestylePlan()
    plan.income = 300000; plan.monthlySpending = 280000
    plan.flexibleSpending = 100000; plan.reductionPercent = 10
    plan.reserve = 20000; plan.otherCommitments = 20000
    #expect(plan.potentialReduction == 10000)
    #expect(plan.availableAfterChanges == 0)
    #expect(plan.shortfall == 10000)
    plan.flexibleSpending = 0
    #expect(plan.potentialReduction == 0)
}
@Test func projectionsIncludeZeroAndNegativeReturns() {
    #expect(Planning.futureValue(monthly: 10000, years: 10, annualPercent: 0) == 1200000)
    #expect(Planning.futureValue(monthly: 10000, years: 10, annualPercent: -5)! < 1200000)
    #expect(Planning.futureValue(monthly: 10000, years: 10, annualPercent: 5)! > 1200000)
    #expect(Planning.futureValue(monthly: 10000, years: 10, annualPercent: .nan) == nil)
    #expect(Planning.independenceTarget(annualSpending: 4800000, withdrawalPercent: 4) == 120000000)
}
@Test func planningSnapshotRoundTrips() throws {
    var snapshot = PlanningSnapshot()
    snapshot.goals = [SavingsGoal(name: "Trip", kind: .holiday, target: 100000, saved: 25000, deadline: Date(timeIntervalSince1970: 1800000000))]
    snapshot.lifestyle.protectedCategories = [UUID()]
    let decoded = try JSONDecoder().decode(PlanningSnapshot.self, from: JSONEncoder().encode(snapshot))
    #expect(decoded == snapshot)
}
