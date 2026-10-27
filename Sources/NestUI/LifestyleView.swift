import SwiftUI
import NestCore

struct LifestyleView: View {
    let entries: [Entry]
    let categories: [NestCore.Category]
    @Environment(\.workspaceMode) private var mode
    @Environment(PlanningStore.self) private var plans
    @State private var income = "0"
    @State private var spending = "0"
    @State private var reserve = "0"
    @State private var commitments = "0"
    @State private var reduction = 10.0
    @State private var protected: Set<UUID> = []
    @State private var risk = "Balanced"
    @State private var confirmed = false
    @State private var loaded = false
    @State private var rate = 3.0
    @State private var years = 10
    @State private var message: String?

    private var baseline: [Entry] { Ledger.entries(entries, month: .now) }
    private var totals: [CategoryTotal] { Ledger.spending(baseline, categories: categories) }
    private var result: LifestylePlan? {
        guard let income = amountOrZero(income), let spending = amountOrZero(spending),
              let reserve = amountOrZero(reserve), let commitments = amountOrZero(commitments) else { return nil }
        var plan = LifestylePlan()
        plan.income = income; plan.monthlySpending = spending; plan.reserve = reserve; plan.otherCommitments = commitments
        plan.reductionPercent = reduction; plan.protectedCategories = Array(protected); plan.riskPreference = risk; plan.confirmed = confirmed
        let recorded = totals.reduce(Int64(0)) { $0 + $1.cents }
        let flexible = totals.filter { !protected.contains($0.id) }.reduce(Int64(0)) { $0 + $1.cents }
        plan.flexibleSpending = recorded > 0 ? Int64((Double(spending) * Double(flexible) / Double(recorded)).rounded(.down)) : 0
        return plan
    }
    var body: some View {
        Form {
            Section {
                Text("Keep the things you love.").font(.title2.bold())
                Text("Choose what stays, then explore a small change elsewhere. This is a budget scenario, not an instruction to invest.")
            }
            Section("Your typical month · AUD") {
                TextField("Take-home income", text: $income)
                TextField("Total spending, including loan payments", text: $spending)
                TextField("Reserve for irregular bills & emergencies", text: $reserve)
                TextField("Goal saving or payments not already included", text: $commitments)
                Text("Enter full-month amounts. Include debt payments once. Keep money for upcoming bills and goals out of the investment scenario.").font(.caption)
                Button("Start with this month’s recorded totals") {
                    income = editableAmount(Ledger.total(baseline, kind: .income))
                    spending = editableAmount(Ledger.total(baseline, kind: .expense))
                    confirmed = false
                }
                Text(mode == .demo ? "Recorded totals are incomplete sample data; adjust them before confirming." : "Recorded totals may be incomplete; check the amounts before confirming.").font(.caption).foregroundStyle(.secondary)
            }
            Section("What would you like to protect?") {
                ForEach(categories) { category in
                    Toggle(category.name, isOn: Binding(get: { protected.contains(category.id) }, set: { keep in
                        if keep { protected.insert(category.id) } else { protected.remove(category.id) }
                        confirmed = false
                    }))
                }
                Text("Protected categories get no suggested cuts. Flexible spending is estimated using this month’s recorded category proportions; missing or unusual transactions can distort it.").font(.caption)
                Text("Trim flexible spending by \(Int(reduction))%")
                Slider(value: $reduction, in: 0...30, step: 1)
            }
            Section("Your comfort with risk") {
                Picker("Preference", selection: $risk) {
                    ForEach(["Cautious", "Balanced", "Growth-focused"], id: \.self) { Text($0).tag($0) }
                }
                Text("Saved as a preference, not a suitability assessment. It does not change the money you can afford to set aside or select investments for you.").font(.caption)
            }
            Section {
                Toggle("I’ve checked these are realistic full-month amounts", isOn: $confirmed)
                if let plan = result, confirmed {
                    LabeledContent("Potential spending reduction", value: Money.text(plan.potentialReduction))
                    if plan.shortfall > 0 {
                        Text("There is still a \(Money.text(plan.shortfall)) monthly gap. Let’s focus on balancing the budget first.")
                    } else {
                        LabeledContent("Unallocated after your changes", value: Money.text(plan.availableAfterChanges))
                        Text("You choose whether this goes to a buffer, debt, a goal or investing. It is not a guaranteed safe-to-invest amount.").font(.caption)
                    }
                    Button("Save my plan") {
                        do { try plans.update { $0.lifestyle = plan }; message = "Your plan is saved. You can adjust it anytime." }
                        catch { message = "That didn’t save. Please try again." }
                    }
                    if plan.availableAfterChanges > 0 { projection(plan) }
                } else {
                    Text("Check the amounts and confirm your full-month budget to see the scenario.").foregroundStyle(.secondary)
                }
                if let message { Text(message).font(.footnote) }
            } header: { Text("A little room to grow") }
        }.navigationTitle("Your lifestyle plan")
            .onAppear {
                guard !loaded else { return }; loaded = true
                let plan = plans.snapshot.lifestyle
                income = editableAmount(plan.income); spending = editableAmount(plan.monthlySpending)
                reserve = editableAmount(plan.reserve); commitments = editableAmount(plan.otherCommitments)
                reduction = plan.reductionPercent; protected = Set(plan.protectedCategories); risk = plan.riskPreference
                // Reconfirm against the current transaction mix before producing a fresh scenario.
                confirmed = false
            }
            .onChange(of: income) { confirmed = false }
            .onChange(of: spending) { confirmed = false }
            .onChange(of: reserve) { confirmed = false }
            .onChange(of: commitments) { confirmed = false }
            .onChange(of: reduction) { confirmed = false }
    }
    private func projection(_ plan: LifestylePlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Explore a hypothetical investment").font(.headline)
            Stepper("\(years) years", value: $years, in: 1...30)
            Text("Assumed annual return: \(rate, specifier: "%.1f")%")
            Slider(value: $rate, in: -10...12, step: 0.5)
            if let value = Planning.futureValue(monthly: plan.availableAfterChanges, years: years, annualPercent: rate) {
                Text(Money.text(value)).font(.title2.bold())
                Text("Contributions: \(Money.text(plan.availableAfterChanges * Int64(years * 12)))").font(.caption)
            }
            Text("An illustration with a constant return and end-of-month contributions. Excludes taxes, fees and inflation. Actual returns vary and losses are possible; this is not a forecast or product recommendation.").font(.caption)
        }.padding(.vertical, 8)
    }
}
