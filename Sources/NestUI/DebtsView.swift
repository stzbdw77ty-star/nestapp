import SwiftUI
import Charts
import NestCore

struct DebtsView: View {
    @Environment(PlanningStore.self) private var plans
    @State private var draft: DebtDraft?
    var body: some View {
        List {
            Section {
                Text("A little lighter, payment by payment.").font(.title2.bold())
                Text("Explore how extra repayments could change your timeline.").foregroundStyle(.secondary)
            }
            ForEach(plans.snapshot.debts) { debt in
                Button { draft = DebtDraft(debt: debt) } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(debt.name).font(.headline)
                        Text(Money.text(debt.balance)).font(.title2.bold())
                        if let schedule = Planning.payoff(debt) {
                            Text("\(schedule.months) months · \(Money.text(schedule.interest)) estimated interest")
                                .font(.subheadline)
                            Chart(schedule.points) { point in
                                AreaMark(x: .value("Month", point.month), y: .value("Balance in AUD", Double(point.balance) / 100))
                                    .foregroundStyle(NestTheme.colour("lilac").opacity(0.25))
                                LineMark(x: .value("Month", point.month), y: .value("Balance in AUD", Double(point.balance) / 100))
                                    .foregroundStyle(NestTheme.accent)
                            }.frame(height: 130).chartXAxisLabel("Months")
                            if let baseline = Planning.payoff(debt, includeExtra: false), debt.extra > 0 {
                                Text("Your extra payment could save \(baseline.months - schedule.months) months and \(Money.text(max(0, baseline.interest - schedule.interest))) in interest.")
                                    .font(.caption)
                            }
                        } else { Text("This payment does not clear the balance within 50 years. Try a higher repayment.").font(.subheadline) }
                    }.padding(.vertical, 8).foregroundStyle(.primary)
                }.buttonStyle(.plain)
            }
            if plans.snapshot.debts.isEmpty {
                ContentUnavailableView("Make a repayment plan", systemImage: "arrow.down.right.circle", description: Text("Add a loan or credit card to explore a payoff timeline."))
            }
            Section {
                Text("Estimates use a fixed APR divided by 12, monthly interest rounded to cents and end-of-month repayments. They exclude fees, new borrowing and rate changes. Check your lender’s actual terms.").font(.caption)
            }
        }.navigationTitle("Debts & loans")
            .toolbar { Button { draft = DebtDraft() } label: { Label("Add debt", systemImage: "plus") } }
            .sheet(item: $draft) { DebtEditor(draft: $0) }
    }
}
private struct DebtDraft: Identifiable { let id = UUID(); var debt: Debt? }
private struct DebtEditor: View {
    let draft: DebtDraft
    @Environment(PlanningStore.self) private var plans
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var balance: String
    @State private var apr: Double
    @State private var payment: String
    @State private var extra: String
    @State private var error: String?
    @State private var confirmDelete = false
    init(draft: DebtDraft) {
        self.draft = draft
        _name = State(initialValue: draft.debt?.name ?? "")
        _balance = State(initialValue: draft.debt.map { editableAmount($0.balance) } ?? "")
        _apr = State(initialValue: draft.debt?.annualRatePercent ?? 6)
        _payment = State(initialValue: draft.debt.map { editableAmount($0.payment) } ?? "")
        _extra = State(initialValue: draft.debt.map { editableAmount($0.extra) } ?? "0")
    }
    var body: some View {
        NavigationStack {
            Form {
                TextField("Loan or card name", text: $name)
                TextField("Current balance (AUD)", text: $balance)
                TextField("Annual interest rate (%)", value: $apr, format: .number)
                TextField("Monthly repayment (AUD)", text: $payment)
                TextField("Extra per month (AUD)", text: $extra)
                Text("Update the balance as you pay it down. This planner does not move money.").font(.caption)
                if let error { Text(error).foregroundStyle(.red) }
                if draft.debt != nil { Button("Delete debt", role: .destructive) { confirmDelete = true } }
            }.navigationTitle("Your repayment plan")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
                }
                .confirmationDialog("Delete this debt plan?", isPresented: $confirmDelete) {
                    Button("Delete plan", role: .destructive) {
                        do { try plans.update { $0.debts.removeAll { $0.id == draft.debt?.id } }; dismiss() }
                        catch { self.error = "Couldn’t save that change." }
                    }
                }
        }.frame(minWidth: 320, minHeight: 420)
    }
    private func save() {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 60, let balance = amountOrZero(balance), let payment = Money.parse(payment), let extra = amountOrZero(extra), apr.isFinite, (0...100).contains(apr) else {
            error = "Check the amounts and use an interest rate from 0 to 100%."; return
        }
        let debt = Debt(id: draft.debt?.id ?? UUID(), name: title, balance: balance, annualRatePercent: apr, payment: payment, extra: extra)
        do {
            try plans.update { snapshot in
                if let index = snapshot.debts.firstIndex(where: { $0.id == debt.id }) { snapshot.debts[index] = debt }
                else { snapshot.debts.append(debt) }
            }; dismiss()
        } catch { self.error = "That didn’t save. Please try again." }
    }
}
