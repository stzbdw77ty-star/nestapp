import SwiftUI
import NestCore

struct TransactionScreen: View {
    let categories: [NestCore.Category]
    let entries: [Entry]
    let onAdd: () -> Void
    let onCategories: () -> Void
    let onOpen: (UUID) -> Void
    @Environment(\.workspaceMode) private var mode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var month = Date.now
    @State private var search = ""
    @State private var filter = "all"
    @State private var categoryID: UUID?
    private var monthly: [Entry] { Ledger.entries(entries, month: month) }
    private var categoryValues: [NestCore.Category] { categories }
    private var visible: [Entry] {
        monthly.filter { entry in
            (filter == "all" || entry.kind.rawValue == filter)
            && (categoryID == nil || entry.categoryID == categoryID)
            && (search.isEmpty || entry.merchant.localizedCaseInsensitiveContains(search)
                || categoryValues.first(where: { $0.id == entry.categoryID })?.name.localizedCaseInsensitiveContains(search) == true)
        }
    }
    private var availableMonths: [Date] {
        let calendar = Calendar.current
        let dates = entries.map(\.date) + (0..<12).compactMap {
            calendar.date(byAdding: .month, value: -$0, to: .now)
        }
        return Set(dates.compactMap { calendar.dateInterval(of: .month, for: $0)?.start }).sorted(by: >)
    }
    private var days: [Date] {
        Array(Set(visible.map { Calendar.current.startOfDay(for: $0.date) })).sorted(by: >)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                pageContent
            }
            .background(NestTheme.canvas)
            .navigationTitle("Nest")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { onAdd() } label: { Label("Add transaction", systemImage: "plus") }
                        .accessibilityIdentifier("addTransaction")
                }
                ToolbarItem(placement: .automatic) {
                    Button { onCategories() } label: { Label("Categories", systemImage: "slider.horizontal.3") }
                        .accessibilityIdentifier("manageCategories")
                }
            }

        }
        .tint(NestTheme.accent)
        .fontDesign(.rounded)
    }

    var pageContent: some View {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    SummaryCard(entries: monthly)
                    SpendingCard(totals: Ledger.spending(monthly, categories: categoryValues), selectedID: $categoryID)
                    transactions
                    Text("A little clarity, one transaction at a time.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).padding(.bottom, 12)
                }
                .padding(20).frame(maxWidth: 650)
                .frame(maxWidth: .infinity)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("YOUR MONEY, A LITTLE CLEARER", systemImage: "sun.max")
                    .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            Text("Make room for\nwhat you love.").font(.largeTitle.bold())
            Text("Let’s see where your money’s been going.")
                .foregroundStyle(.secondary)
            HStack {
                Label(mode == .demo ? "Sample data" : "On this device", systemImage: mode == .demo ? "leaf" : "lock.shield")
                    .font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8)
                    .background(NestTheme.colour("mint").opacity(0.2), in: .capsule)
                Spacer()
                Menu {
                    ForEach(availableMonths, id: \.self) { date in
                        Button(date.formatted(.dateTime.month(.wide).year())) {
                            month = date; categoryID = nil
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(month.formatted(.dateTime.month(.abbreviated).year()))
                        Image(systemName: "chevron.down").font(.caption)
                    }.font(.subheadline.weight(.semibold)).padding(.vertical, 8)
                }.accessibilityLabel("Month, \(month.formatted(.dateTime.month(.wide).year()))")
            }
            Text(mode == .demo ? "A practice space. No bank accounts are connected." : "Your manual records. No bank accounts are connected.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var transactions: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your transactions").font(.title2.bold())
                Spacer()
                Text("\(visible.count)").font(.subheadline).foregroundStyle(.secondary)
            }
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Find a merchant or category", text: $search)
                    .textFieldStyle(.plain).accessibilityIdentifier("transactionSearch")
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .accessibilityLabel("Clear search")
                }
            }.padding(14).background(.primary.opacity(0.045), in: .rect(cornerRadius: 15))
            Picker("Transaction type", selection: $filter) {
                Text("All").tag("all")
                Text("Out").tag("expense")
                Text("In").tag("income")
                Text("Transfers").tag("transfer")
            }.pickerStyle(.segmented)
            if let categoryID, let category = categoryValues.first(where: { $0.id == categoryID }) {
                Button {
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) { self.categoryID = nil }
                } label: {
                    Label("\(category.name) · Clear filter", systemImage: "xmark.circle")
                        .font(.subheadline)
                }
            }
            if visible.isEmpty {
                ContentUnavailableView("A fresh little space", systemImage: "tray",
                                       description: Text("No transactions match. Try another month or filter, or add one with +."))
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(days, id: \.self) { day in
                        Text(day.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 14).padding(.bottom, 8)
                        ForEach(visible.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }) { entry in
                            Button {
                                onOpen(entry.id)
                            } label: {
                                TransactionRow(entry: entry, category: categoryValues.first { $0.id == entry.categoryID })
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("View or edit this transaction")
                            Divider().opacity(0.45)
                        }
                    }
                }
            }
        }.nestCard()
    }
}

private struct TransactionRow: View {
    let entry: Entry
    let category: NestCore.Category?
    private var amount: String {
        let sign = entry.kind == .income ? "+" : entry.kind == .expense ? "−" : "↔ "
        return sign + Money.text(entry.cents)
    }
    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(symbol: category?.symbol ?? "tag", colour: category?.colour ?? "lilac")
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.merchant).font(.subheadline.weight(.semibold))
                Text((category?.name ?? "Uncategorised") + (entry.pending ? " · Pending" : ""))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Text(amount).font(.subheadline.weight(.semibold)).monospacedDigit()
                .foregroundStyle(entry.kind == .income ? NestTheme.accent : .primary)
        }.padding(.vertical, 12).contentShape(.rect)
            .accessibilityElement(children: .combine)
    }
}

private struct SummaryCard: View {
    let entries: [Entry]
    private var income: Int64 { Ledger.total(entries, kind: .income) }
    private var expenses: Int64 { Ledger.total(entries, kind: .expense) }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Your month so far", systemImage: "sparkles").font(.headline)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 32) { metric("Money in", income); metric("Money out", expenses) }
                VStack(alignment: .leading, spacing: 16) { metric("Money in", income); metric("Money out", expenses) }
            }
            Divider()
            Text("\(Money.text(income - expenses)) net cash flow")
                .font(.headline)
            Text("Income minus spending. This is not your bank balance or an amount safe to spend. Pending transactions and transfers are excluded.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22).frame(maxWidth: .infinity, alignment: .leading)
        .background(NestTheme.colour("lilac").opacity(0.21), in: .rect(cornerRadius: 26))
    }
    private func metric(_ title: String, _ cents: Int64) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(Money.text(cents)).font(.title2.bold()).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
