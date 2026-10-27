import SwiftUI
import SwiftData
import NestCore

struct AccountsView: View {
    @Query private var entries: [TransactionRecord]
    @Query private var categories: [CategoryRecord]
    @Environment(PlanningStore.self) private var plans
    @State private var adding = false
    @State private var journal = false
    private var book: AccountingBook? {
        try? AccountingBook(categories: categories.map(\.value), entries: entries.map(\.value), books: plans.snapshot.books)
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Every account, a clearer picture.").font(.title2.bold())
                    Text("Balances come from posted records and opening balances you enter. They are not live bank balances.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let book {
                    let rows = book.trialBalance(through: .now)
                    let assets = rows.filter { $0.account.kind == .asset }.reduce(0) { $0 + $1.normalBalance }
                    let liabilities = rows.filter { $0.account.kind == .liability }.reduce(0) { $0 + $1.normalBalance }
                    Section("Recorded net worth") {
                        Text(Money.text(assets - liabilities)).font(.largeTitle.bold()).monospacedDigit()
                        LabeledContent("Assets", value: Money.text(assets))
                        LabeledContent("Debts", value: Money.text(liabilities))
                        Text("Only accounts and transactions recorded here are included. Goal balances are planning notes, not additional assets.").font(.caption)
                    }
                    ForEach([AccountKind.asset, .liability], id: \.self) { kind in
                        Section(kind == .asset ? "Money & assets" : "Cards & debts") {
                            ForEach(rows.filter { $0.account.kind == kind }) { row in
                                NavigationLink {
                                    AccountDetailView(account: row.account)
                                } label: {
                                    HStack {
                                        Label(row.account.name, systemImage: kind == .asset ? "building.columns" : "creditcard")
                                        Spacer()
                                        Text(Money.text(row.normalBalance)).monospacedDigit()
                                    }
                                }
                            }
                        }
                    }
                    Section {
                        Button("Add an account", systemImage: "plus.circle") { adding = true }
                        Button("Record an opening balance or adjustment", systemImage: "equal.circle") { journal = true }
                        Text("Opening balances and loan proceeds are not income. Use an adjustment for these; everyday income and spending go in Activity.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    ContentUnavailableView("Accounts need attention", systemImage: "exclamationmark.triangle", description: Text("A posting references an unavailable account. Export a backup in More before making changes."))
                }
            }.navigationTitle("Your accounts").nestPage()
                .sheet(isPresented: $adding) { AddAccountView() }
                .sheet(isPresented: $journal) { JournalEditor() }
        }
    }
}

private struct AddAccountView: View {
    @Environment(PlanningStore.self) private var plans
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var kind = AccountKind.asset
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                TextField("Account name", text: $name)
                Picker("Account type", selection: $kind) {
                    Text("Bank / cash (asset)").tag(AccountKind.asset)
                    Text("Credit card / loan (liability)").tag(AccountKind.liability)
                }
                Text("Use Activity for spending, income or transfers. Enter an existing balance with an opening-balance adjustment. A positive credit-card balance means money you owe.").font(.footnote)
                if let error { Text(error).foregroundStyle(.red) }
            }.navigationTitle("New account")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
                }
        }
    }
    private func save() {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let existing = ChartOfAccounts.defaults + plans.snapshot.books.accounts
        guard !title.isEmpty, title.count <= 60,
              !existing.contains(where: { $0.name.localizedCaseInsensitiveCompare(title) == .orderedSame }) else {
            error = "Choose a unique name of up to 60 characters."; return
        }
        do {
            try plans.update { $0.books.accounts.append(LedgerAccount(name: title, kind: kind, isBank: true)) }
            dismiss()
        } catch { self.error = "That account didn’t save. Please try again." }
    }
}

private struct AccountDetailView: View {
    let account: LedgerAccount
    @Query private var entries: [TransactionRecord]
    @Query private var categories: [CategoryRecord]
    @Environment(PlanningStore.self) private var plans
    @State private var statement = ""
    @State private var date = Date.now
    @State private var message: String?
    @State private var confirmReconcile = false
    @State private var confirmUnlock = false
    private var book: AccountingBook? { try? AccountingBook(categories: categories.map(\.value), entries: entries.map(\.value), books: plans.snapshot.books) }
    private var cutoff: Date {
        (Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: date)) ?? date).addingTimeInterval(-0.001)
    }
    private var statementCents: Int64? {
        let value = statement.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("-"), let amount = Money.parse(String(value.dropFirst())) { return -amount }
        return amountOrZero(value)
    }
    private var reconciliations: [Reconciliation] {
        plans.snapshot.books.reconciliations.filter { $0.accountID == account.id }.sorted { $0.date > $1.date }
    }
    var body: some View {
        List {
            if let book {
                Section("Recorded balance") {
                    Text(Money.text(book.balance(accountID: account.id))).font(.largeTitle.bold())
                    Text(account.kind == .liability ? "Positive means money owed; negative means a credit balance." : "Posted transactions only. Pending entries are excluded.").font(.caption)
                }
                if account.isBank {
                    Section("Check against your statement") {
                        DatePicker("Statement end date", selection: $date, in: ...Date.now, displayedComponents: .date)
                        TextField("Closing balance in AUD", text: $statement)
                            .accessibilityIdentifier("statementBalance")
                        LabeledContent("Nest balance on that date", value: Money.text(book.balance(accountID: account.id, through: cutoff)))
                        if let amount = statementCents {
                            let difference = amount - book.balance(accountID: account.id, through: cutoff)
                            LabeledContent("Difference", value: Money.text(difference))
                            Button("Confirm statement match") { confirmReconcile = true }.disabled(difference != 0)
                        }
                        Text("Add or correct missing entries first. Only an exact match can be confirmed. This checks all posted entries up to the end of that day and locks them against edits. For cards, enter the amount owed as positive.").font(.caption)
                    }
                    if let latest = reconciliations.first {
                        Section("Statement history") {
                            ForEach(reconciliations) { item in
                                LabeledContent(item.date.formatted(date: .abbreviated, time: .omitted), value: Money.text(item.statementBalance))
                            }
                            Button("Remove statement checks to make corrections", role: .destructive) { confirmUnlock = true }
                            Text("Latest check: \(latest.entryIDs.count) posted entries. Removing checks does not delete transactions.").font(.caption)
                        }
                    }
                }
                Section("Posted account activity") {
                    ForEach(book.journals.filter { entry in entry.lines.contains { $0.accountID == account.id } }) { entry in
                        let delta = entry.lines.filter { $0.accountID == account.id }.reduce(0) { $0 + $1.debit - $1.credit }
                        VStack(alignment: .leading, spacing: 5) {
                            HStack { Text(entry.memo); Spacer(); Text(Money.text(account.kind.debitNormal ? delta : -delta)).monospacedDigit() }
                            Text(entry.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if let message { Text(message).font(.footnote) }
        }.navigationTitle(account.name)
            .confirmationDialog("Confirm this statement match?", isPresented: $confirmReconcile) {
                Button("Confirm and lock entries") {
                    guard let book, let amount = statementCents else { return }
                    do {
                        let reconciliation = try book.reconcile(accountID: account.id, through: cutoff, statementBalance: amount)
                        try plans.update { $0.books.reconciliations.append(reconciliation) }
                        message = "Statement matched. The included entries are now locked."
                    } catch { message = "The statement check didn’t save. Please try again." }
                }
            }
            .confirmationDialog("Remove statement checks?", isPresented: $confirmUnlock) {
                Button("Remove checks", role: .destructive) {
                    do { try plans.update { $0.books.reconciliations.removeAll { $0.accountID == account.id } } }
                    catch { message = "That change didn’t save." }
                }
            }
    }
}

private struct LineDraft: Identifiable {
    let id = UUID()
    var accountID: UUID
    var side = "debit"
    var amount = ""
}
struct JournalEditor: View {
    @Environment(PlanningStore.self) private var plans
    @Environment(\.dismiss) private var dismiss
    @Query private var categories: [CategoryRecord]
    @Query private var entries: [TransactionRecord]
    @State private var memo = ""
    @State private var date = Date.now
    @State private var lines = [LineDraft(accountID: ChartOfAccounts.bankID), LineDraft(accountID: ChartOfAccounts.capitalID, side: "credit")]
    @State private var error: String?
    private var accounts: [LedgerAccount] { ChartOfAccounts.accounts(categories: categories.map(\.value), custom: plans.snapshot.books.accounts) }
    private var journal: JournalEntry? {
        var postings: [JournalLine] = []
        for line in lines {
            guard let amount = Money.parse(line.amount) else { return nil }
            postings.append(JournalLine(accountID: line.accountID, debit: line.side == "debit" ? amount : 0, credit: line.side == "credit" ? amount : 0))
        }
        return JournalEntry(memo: memo, date: date, lines: postings)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Description, e.g. Opening balances", text: $memo)
                    DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date)
                    Text("Advanced adjustment: debits and credits must balance. To enter an existing bank balance, debit the bank and credit opening equity. For existing card debt, debit opening equity and credit the card. Loan proceeds debit your bank and credit Loans payable.").font(.caption)
                }
                ForEach($lines) { $line in
                    Section("Posting") {
                        Picker("Account", selection: $line.accountID) {
                            ForEach(accounts) { Text("\($0.name) · \($0.kind.title)").tag($0.id) }
                        }
                        Picker("Side", selection: $line.side) { Text("Debit").tag("debit"); Text("Credit").tag("credit") }
                            .pickerStyle(.segmented)
                        TextField("Amount (AUD)", text: $line.amount)
                        if lines.count > 2 { Button("Remove line", role: .destructive) { lines.removeAll { $0.id == line.id } } }
                    }
                }
                Button("Add a posting line") { lines.append(LineDraft(accountID: ChartOfAccounts.bankID)) }.disabled(lines.count >= 20)
                if let journal {
                    LabeledContent("Debits", value: Money.text(journal.lines.reduce(0) { $0 + $1.debit }))
                    LabeledContent("Credits", value: Money.text(journal.lines.reduce(0) { $0 + $1.credit }))
                }
                if let error { Text(error).foregroundStyle(.red) }
            }.navigationTitle("Balance adjustment")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
                }
        }
    }
    private func save() {
        do {
            guard let journal else { throw AccountingError.invalidJournal }
            try journal.validate(accounts: accounts)
            var next = plans.snapshot.books
            next.journals.append(journal)
            let book = try AccountingBook(categories: categories.map(\.value), entries: entries.map(\.value), books: next)
            // A backdated adjustment must never silently invalidate a checked statement.
            for item in next.reconciliations {
                let check = try book.reconcile(accountID: item.accountID, through: item.date, statementBalance: item.statementBalance)
                guard Set(check.entryIDs) == Set(item.entryIDs) else { throw AccountingError.invalidAccounts }
            }
            try plans.update { $0.books = next }
            dismiss()
        } catch { self.error = "\(error.localizedDescription) If this changes a checked statement, remove that check in Accounts first." }
    }
}
