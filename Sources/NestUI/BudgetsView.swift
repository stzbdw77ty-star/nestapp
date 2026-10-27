import SwiftUI
import SwiftData
import NestCore

struct BudgetsView: View {
    @Environment(PlanningStore.self) private var plans
    @Query private var entries: [TransactionRecord]
    @Query(sort: \CategoryRecord.name) private var categories: [CategoryRecord]
    @State private var month = Date.now
    @State private var editing = false
    @State private var selectedCategory: UUID?
    @State private var amount = ""
    @State private var message: String?
    private var calendar: Calendar { .current }
    private var budgets: [MonthlyBudget] {
        plans.snapshot.books.budgets.filter { $0.year == calendar.component(.year, from: month) && $0.month == calendar.component(.month, from: month) }
    }
    private var spending: [UUID: Int64] {
        guard let period = calendar.dateInterval(of: .month, for: month),
              let book = try? AccountingBook(categories: categories.map(\.value), entries: entries.map(\.value), books: plans.snapshot.books) else { return [:] }
        return Dictionary(uniqueKeysWithValues: book.trialBalance(through: period.end.addingTimeInterval(-0.001), since: period.start).filter { $0.account.kind == .expense }.map { ($0.id, $0.normalBalance) })
    }
    var body: some View {
        List {
            Section {
                Text("Give every month a little direction.").font(.title2.bold())
                MonthControl(month: $month)
                Text("Set a spending limit for each category. Limits are for this month only; they do not move or reserve money.").font(.footnote).foregroundStyle(.secondary)
            }
            if budgets.isEmpty {
                ContentUnavailableView("A plan for your month", systemImage: "chart.pie", description: Text("Add your first category budget to see what’s left as you spend."))
            }
            ForEach(budgets) { budget in
                let spent = spending[budget.categoryID, default: 0]
                let remaining = budget.limit - spent
                Button {
                    selectedCategory = budget.categoryID; amount = editableAmount(budget.limit); editing = true
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(categories.first { $0.id == budget.categoryID }?.name ?? "Category").font(.headline)
                            Spacer()
                            Text(remaining >= 0 ? "\(Money.text(remaining)) left" : "\(Money.text(-remaining)) over")
                                .foregroundStyle(remaining >= 0 ? NestTheme.accent : .red)
                        }
                        ProgressView(value: min(1, max(0, Double(spent) / Double(budget.limit))))
                            .tint(remaining >= 0 ? NestTheme.accent : .red)
                        Text("\(Money.text(spent)) of \(Money.text(budget.limit))").font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 10).foregroundStyle(.primary)
                }.buttonStyle(.plain)
            }
            if let message { Text(message).font(.footnote) }
            Section { Text("Posted expenses and expense adjustments count towards budgets. Pending payments and transfers don’t. Goals and budgets are planning aids, so they are not added to account balances.").font(.caption) }
        }.navigationTitle("Monthly budgets").nestPage()
            .toolbar { Button { selectedCategory = nil; amount = ""; editing = true } label: { Label("Add budget", systemImage: "plus") } }
            .sheet(isPresented: $editing) {
                NavigationStack {
                    Form {
                        Picker("Category", selection: $selectedCategory) {
                            Text("Choose a category").tag(Optional<UUID>.none)
                            ForEach(categories) { Text($0.name).tag(Optional($0.id)) }
                        }
                        TextField("Monthly limit in AUD", text: $amount)
                        Text("Saves a limit for \(month.formatted(.dateTime.month(.wide).year())). Saving an existing category updates its limit.").font(.caption)
                        if let id = selectedCategory, budgets.contains(where: { $0.categoryID == id }) {
                            Button("Remove this budget", role: .destructive) {
                                do { try plans.update { $0.books.budgets.removeAll { $0.categoryID == id && $0.year == calendar.component(.year, from: month) && $0.month == calendar.component(.month, from: month) } }; editing = false }
                                catch { message = "That budget didn’t save." }
                            }
                        }
                    }.navigationTitle("Category budget")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { editing = false } }
                            ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(selectedCategory == nil || Money.parse(amount) == nil) }
                        }
                }
            }
    }
    private func save() {
        guard let categoryID = selectedCategory, let limit = Money.parse(amount) else { return }
        let year = calendar.component(.year, from: month), number = calendar.component(.month, from: month)
        do {
            try plans.update {
                if let index = $0.books.budgets.firstIndex(where: { $0.categoryID == categoryID && $0.year == year && $0.month == number }) {
                    $0.books.budgets[index].limit = limit
                } else { $0.books.budgets.append(MonthlyBudget(categoryID: categoryID, year: year, month: number, limit: limit)) }
            }
            editing = false
        } catch { message = "Your budget didn’t save. Please try again." }
    }
}

struct MonthControl: View {
    @Binding var month: Date
    var body: some View {
        HStack {
            Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel("Previous month")
            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year())).font(.headline)
            Spacer()
            Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.accessibilityLabel("Next month")
        }.buttonStyle(.plain)
    }
    private func move(_ offset: Int) {
        let start = Calendar.current.dateInterval(of: .month, for: month)?.start ?? month
        if let next = Calendar.current.date(byAdding: .month, value: offset, to: start) { month = next }
    }
}
