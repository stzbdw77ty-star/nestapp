import SwiftUI
import SwiftData
import NestCore

struct OverviewView: View {
    @Query private var records: [TransactionRecord]
    @Query private var categories: [CategoryRecord]
    @Environment(PlanningStore.self) private var plans
    @Environment(\.workspaceMode) private var mode
    @State private var sheet: QuickEntry?
    private enum QuickEntry: String, Identifiable {
        case expense, transfer
        var id: String { rawValue }
    }
    private var book: AccountingBook? {
        try? AccountingBook(categories: categories.map(\.value), entries: records.map(\.value), books: plans.snapshot.books)
    }
    private var start: Date { Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if let book {
                        balanceCard(book)
                        quickActions
                        if records.isEmpty && plans.snapshot.books.journals.isEmpty { firstSteps }
                        monthCard(book)
                        accountCards(book)
                        budgetCard(book)
                        recentActivity
                    } else {
                        ContentUnavailableView("Let’s check your accounts", systemImage: "exclamationmark.triangle", description: Text("A posting needs attention. Export your records in More → Workspace & data before making changes."))
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield")
                        Text(mode == .demo ? "Fictional sample data · Personal records are separate" : "On this device · No bank connection")
                    }.font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.bottom, 12)
                }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
            }.nestPage().navigationTitle("Overview")
                #if os(iOS)
                .toolbar(.hidden, for: .navigationBar)
                #endif
                .sheet(item: $sheet) { item in AddTransactionView(kind: item == .transfer ? .transfer : .expense) }
        }
    }
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill").foregroundStyle(NestTheme.accent)
                    Text("nest").font(.title2.bold())
                }
                Text(Date.now.formatted(.dateTime.month(.wide).year())).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            NavigationLink { WorkspaceSettingsView() } label: {
                Image(systemName: mode == .demo ? "leaf" : "person.crop.circle")
                    .font(.title2).frame(width: 48, height: 48)
                    .background(NestTheme.colour("lilac").opacity(0.18), in: .circle)
            }.accessibilityLabel("Workspace and settings")
        }
    }
    private func balanceCard(_ book: AccountingBook) -> some View {
        let rows = book.trialBalance(through: .now)
        let assets = rows.filter { $0.account.kind == .asset }.reduce(0) { $0 + $1.normalBalance }
        let debts = rows.filter { $0.account.kind == .liability }.reduce(0) { $0 + $1.normalBalance }
        return VStack(alignment: .leading, spacing: 22) {
            HStack {
                Label("RECORDED NET WORTH", systemImage: "circle.grid.2x2.fill").font(.caption.weight(.semibold))
                Spacer()
                if mode == .demo { Text("DEMO").font(.caption2.bold()).padding(.horizontal, 10).padding(.vertical, 6).background(.white.opacity(0.16), in: .capsule) }
            }.foregroundStyle(.white.opacity(0.8))
            Text(Money.text(assets - debts)).font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit().foregroundStyle(.white).contentTransition(.numericText())
            Text("A little clarity. More room for life.").font(.subheadline).foregroundStyle(.white.opacity(0.78))
            Divider().overlay(.white.opacity(0.18))
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 28) { heroMetric("Assets", amount: assets, symbol: "arrow.up.right"); heroMetric("Debts", amount: debts, symbol: "arrow.down.left") }
                VStack(alignment: .leading, spacing: 14) { heroMetric("Assets", amount: assets, symbol: "arrow.up.right"); heroMetric("Debts", amount: debts, symbol: "arrow.down.left") }
            }
            Text("Based on what you’ve recorded, not a live bank balance.").font(.caption2).foregroundStyle(.white.opacity(0.7))
        }.padding(26).frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [Color(red: 0.26, green: 0.18, blue: 0.43), Color(red: 0.43, green: 0.31, blue: 0.65)], startPoint: .topLeading, endPoint: .bottomTrailing), in: .rect(cornerRadius: 30))
            .overlay(alignment: .topTrailing) {
                Image(systemName: "leaf").font(.system(size: 125)).rotationEffect(.degrees(-25)).foregroundStyle(.white.opacity(0.05)).padding(30).accessibilityHidden(true).allowsHitTesting(false)
            }
    }
    private func heroMetric(_ title: String, amount: Int64, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.caption.bold()).frame(width: 30, height: 30).background(.white.opacity(0.12), in: .circle)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption).foregroundStyle(.white.opacity(0.75))
                Text(Money.text(amount)).font(.headline).monospacedDigit()
            }
        }.foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading)
    }
    private var quickActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { addButton; transferButton }
            VStack(spacing: 12) { addButton; transferButton }
        }
    }
    private var addButton: some View {
        Button { sheet = .expense } label: {
            Label("Add transaction", systemImage: "plus").font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 16)
                .foregroundStyle(.white).background(NestTheme.accent, in: .rect(cornerRadius: 17))
        }.buttonStyle(.plain).accessibilityIdentifier("homeAddTransaction")
    }
    private var transferButton: some View {
        Button { sheet = .transfer } label: {
            Label("Transfer", systemImage: "arrow.left.arrow.right").font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 16)
                .foregroundStyle(NestTheme.accent).background(NestTheme.colour("lilac").opacity(0.16), in: .rect(cornerRadius: 17))
        }.buttonStyle(.plain)
    }
    private var firstSteps: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("YOUR FIRST LITTLE STEP", systemImage: "sparkles").font(.caption.bold()).foregroundStyle(NestTheme.accent)
            Text("Start with what you have.").font(.title3.bold())
            Text("Add your existing bank or card balances, then record transactions from that point onward.").font(.subheadline).foregroundStyle(.secondary)
            NavigationLink { AccountsView() } label: { Label("Set up my accounts", systemImage: "arrow.right") }.font(.subheadline.bold())
        }.nestCard()
    }
    private func monthCard(_ book: AccountingBook) -> some View {
        let rows = book.trialBalance(through: .now, since: start)
        let income = rows.filter { $0.account.kind == .income }.reduce(0) { $0 + $1.normalBalance }
        let spending = rows.filter { $0.account.kind == .expense }.reduce(0) { $0 + $1.normalBalance }
        return VStack(alignment: .leading, spacing: 18) {
            sectionHeading("This month, in focus", destination: ReportsView())
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { flowMetric("Money in", value: income, colour: "mint", symbol: "arrow.down.left"); flowMetric("Money out", value: spending, colour: "peach", symbol: "arrow.up.right") }
                VStack(alignment: .leading, spacing: 16) { flowMetric("Money in", value: income, colour: "mint", symbol: "arrow.down.left"); flowMetric("Money out", value: spending, colour: "peach", symbol: "arrow.up.right") }
            }
            HStack {
                Text(income >= spending ? "Monthly surplus" : "Monthly shortfall").font(.subheadline)
                Spacer()
                Text(Money.text(income - spending)).font(.headline).monospacedDigit().foregroundStyle(income >= spending ? NestTheme.accent : .red)
            }
            Text("Income less posted expenses. Transfers are excluded. This is not an amount safe to spend.").font(.caption).foregroundStyle(.secondary)
        }.nestCard()
    }
    private func flowMetric(_ title: String, value: Int64, colour: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            CategoryIcon(symbol: symbol, colour: colour)
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(Money.text(value)).font(.title3.bold()).monospacedDigit()
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func accountCards(_ book: AccountingBook) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading("Your accounts", destination: AccountsView())
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(book.accounts.filter(\.isBank)) { account in
                        NavigationLink { AccountsView() } label: {
                            VStack(alignment: .leading, spacing: 18) {
                                HStack { Image(systemName: account.kind == .liability ? "creditcard" : "building.columns"); Spacer(); Image(systemName: "arrow.up.right").font(.caption) }
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(account.name).font(.subheadline.weight(.medium)).lineLimit(2)
                                    Text(Money.text(book.balance(accountID: account.id))).font(.title3.bold()).monospacedDigit()
                                }
                                Text(account.kind == .liability ? "Amount owed · manual" : "AUD · manual records").font(.caption2).foregroundStyle(.secondary)
                            }.foregroundStyle(.primary).padding(18).frame(width: 210, alignment: .leading)
                                .background(NestTheme.colour(account.kind == .liability ? "peach" : "mint").opacity(0.17), in: .rect(cornerRadius: 23))
                        }.buttonStyle(.plain).accessibilityHint("Open your accounts")
                    }
                }
            }.scrollIndicators(.hidden)
        }
    }
    private func budgetCard(_ book: AccountingBook) -> some View {
        let calendar = Calendar.current
        let budgets = plans.snapshot.books.budgets.filter { $0.year == calendar.component(.year, from: .now) && $0.month == calendar.component(.month, from: .now) }
        let rows = book.trialBalance(through: .now, since: start)
        return VStack(alignment: .leading, spacing: 18) {
            sectionHeading("Room in your budget", destination: BudgetsView())
            if budgets.isEmpty {
                HStack(alignment: .top, spacing: 14) {
                    CategoryIcon(symbol: "chart.pie", colour: "lilac")
                    VStack(alignment: .leading, spacing: 8) {
                        Text("A plan that fits your life.").font(.headline)
                        Text("Choose monthly limits for the categories that matter to you.").font(.subheadline).foregroundStyle(.secondary)
                        NavigationLink("Create a budget") { BudgetsView() }.font(.subheadline.bold())
                    }
                }
            } else {
                ForEach(Array(budgets.prefix(3))) { budget in
                    let spent = rows.first { $0.id == budget.categoryID }?.normalBalance ?? 0
                    let name = categories.first { $0.id == budget.categoryID }?.name ?? "Category"
                    VStack(alignment: .leading, spacing: 9) {
                        HStack { Text(name).font(.subheadline.bold()); Spacer(); Text(spent > budget.limit ? "\(Money.text(spent - budget.limit)) over" : "\(Money.text(budget.limit - spent)) left").font(.caption).foregroundStyle(spent > budget.limit ? Color.red : Color.secondary) }
                        ProgressView(value: min(1, max(0, Double(spent) / Double(budget.limit)))).tint(spent > budget.limit ? .red : NestTheme.accent)
                        Text("\(Money.text(spent)) of \(Money.text(budget.limit))").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }.nestCard()
    }
    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Latest activity").font(.title3.bold())
            if records.isEmpty {
                Text("Your story starts with the first entry. Add a transaction or import a statement from More.").font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(Array(records.sorted { $0.date > $1.date }.prefix(4))) { record in
                let category = categories.first { $0.id == record.categoryID }
                HStack(spacing: 12) {
                    CategoryIcon(symbol: category?.symbol ?? "tag", colour: category?.colour ?? "lilac")
                    VStack(alignment: .leading, spacing: 5) {
                        Text(record.merchant).font(.subheadline.bold())
                        Text(record.pending ? "Pending" : record.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text((record.value.kind == .income ? "+" : record.value.kind == .expense ? "−" : "↔ ") + Money.text(record.cents))
                        .font(.subheadline.weight(.semibold)).monospacedDigit()
                }.accessibilityElement(children: .combine)
            }
            Text("Edit and filter your records in the Activity tab.").font(.caption).foregroundStyle(.secondary)
        }.nestCard()
    }
    private func sectionHeading<Destination: View>(_ title: String, destination: Destination) -> some View {
        HStack {
            Text(title).font(.title3.bold())
            Spacer()
            NavigationLink { destination } label: { Image(systemName: "arrow.up.right").frame(width: 36, height: 36).background(NestTheme.colour("lilac").opacity(0.12), in: .circle) }
                .accessibilityLabel("Open \(title)")
        }
    }
}
