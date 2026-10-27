import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import NestCore

private struct JournalCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var text: String
    init(text: String = "") { self.text = text }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents, let value = String(data: data, encoding: .utf8) else { throw BackupError.invalid }
        text = value
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: Data(text.utf8)) }
}
struct ReportsView: View {
    @Environment(PlanningStore.self) private var plans
    @Query private var categories: [CategoryRecord]
    @Query private var entries: [TransactionRecord]
    @State private var month = Date.now
    @State private var exporting = false
    @State private var document = JournalCSVDocument()
    @State private var message: String?
    private var book: AccountingBook? { try? AccountingBook(categories: categories.map(\.value), entries: entries.map(\.value), books: plans.snapshot.books) }
    private var period: DateInterval { Calendar.current.dateInterval(of: .month, for: month) ?? DateInterval(start: month, duration: 0) }
    private var end: Date { min(.now, period.end.addingTimeInterval(-0.001)) }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Know where you stand.").font(.title2.bold())
                    MonthControl(month: $month)
                    Text("Reports use posted records only. Transfers, opening balances and loan proceeds do not count as income. This month’s report is incomplete until all entries are recorded.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let book {
                    let monthlyRows = book.trialBalance(through: end, since: period.start)
                    let position = book.trialBalance(through: end)
                    let income = monthlyRows.filter { $0.account.kind == .income }.reduce(0) { $0 + $1.normalBalance }
                    let spending = monthlyRows.filter { $0.account.kind == .expense }.reduce(0) { $0 + $1.normalBalance }
                    Section("Income & spending") {
                        LabeledContent("Income", value: Money.text(income))
                        LabeledContent("Spending", value: Money.text(spending))
                        LabeledContent(income >= spending ? "Surplus" : "Shortfall", value: Money.text(income - spending)).font(.headline)
                        ForEach(monthlyRows.filter { $0.account.kind == .expense && $0.normalBalance != 0 }) { row in
                            LabeledContent(row.account.name, value: Money.text(row.normalBalance)).font(.subheadline)
                        }
                    }
                    Section("Financial position · as of \(end.formatted(date: .abbreviated, time: .omitted))") {
                        let assets = position.filter { $0.account.kind == .asset }.reduce(0) { $0 + $1.normalBalance }
                        let liabilities = position.filter { $0.account.kind == .liability }.reduce(0) { $0 + $1.normalBalance }
                        LabeledContent("Assets", value: Money.text(assets))
                        LabeledContent("Liabilities", value: Money.text(liabilities))
                        LabeledContent("Recorded net worth", value: Money.text(assets - liabilities)).font(.headline)
                        Text("Account balances as of this date, across all recorded history. Manually tracked goals are not counted again as assets.").font(.caption)
                    }
                    Section {
                        NavigationLink("Check the trial balance") { TrialBalanceView(book: book, date: end) }
                        NavigationLink("Adjustments & opening balances") { JournalHistoryView() }
                        Button("Export this month’s journal (CSV)", systemImage: "square.and.arrow.up") {
                            document = JournalCSVDocument(text: book.journalCSV(from: period.start, through: end)); exporting = true
                        }
                    } footer: { Text("CSV includes double-entry postings in AUD for a spreadsheet or accountant. A complete restorable JSON backup is available in More → Workspace & data.") }
                } else {
                    ContentUnavailableView("Reports need attention", systemImage: "exclamationmark.triangle", description: Text("An accounting entry is invalid. Export a backup before making changes."))
                }
                if let message { Text(message) }
            }.navigationTitle("Your reports").nestPage()
                .fileExporter(isPresented: $exporting, document: document, contentType: .commaSeparatedText, defaultFilename: "Nest-journal-\(month.formatted(.dateTime.year().month(.twoDigits)))") { result in
                    if case .failure = result { message = "The report wasn’t exported. Please try again." }
                }
        }
    }
}
private struct TrialBalanceView: View {
    let book: AccountingBook
    let date: Date
    var body: some View {
        let rows = book.trialBalance(through: date)
        List {
            Section {
                Text("Every recorded debit has a matching credit. This check confirms the books balance; it cannot tell whether entries are complete or correctly categorised.").font(.footnote)
            }
            ForEach(AccountKind.allCases) { kind in
                Section(kind.title) {
                    ForEach(rows.filter { $0.account.kind == kind && $0.netDebit != 0 }) { row in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(row.account.name).font(.headline)
                            HStack { Text("Debit \(Money.text(row.debit))"); Spacer(); Text("Credit \(Money.text(row.credit))") }.font(.caption).monospacedDigit()
                        }
                    }
                }
            }
            Section("Totals") {
                let debits = rows.reduce(0) { $0 + $1.debit }
                let credits = rows.reduce(0) { $0 + $1.credit }
                LabeledContent("Debits", value: Money.text(debits))
                LabeledContent("Credits", value: Money.text(credits))
                Label(debits == credits ? "Books balance" : "Out of balance", systemImage: debits == credits ? "checkmark.circle" : "exclamationmark.triangle")
            }
        }.navigationTitle("Trial balance")
    }
}
private struct JournalHistoryView: View {
    @Environment(PlanningStore.self) private var plans
    @Query private var categories: [CategoryRecord]
    @Query private var entries: [TransactionRecord]
    @State private var reversing: JournalEntry?
    @State private var confirmReverse = false
    @State private var message: String?
    var body: some View {
        List {
            Section { Text("Adjustments are kept as a history. To correct one, record a reversing entry, then enter the right amounts. Everyday records are edited in Activity.").font(.footnote) }
            ForEach(plans.snapshot.books.journals.sorted { $0.date > $1.date }) { journal in
                VStack(alignment: .leading, spacing: 8) {
                    Text(journal.memo).font(.headline)
                    Text(journal.date.formatted(date: .abbreviated, time: .omitted)).font(.caption)
                    Text(Money.text(journal.lines.reduce(0) { $0 + $1.debit })).monospacedDigit()
                    Button("Record a reversal") { reversing = journal; confirmReverse = true }
                }
            }
            if plans.snapshot.books.journals.isEmpty { Text("No balance adjustments yet.") }
            if let message { Text(message) }
        }.navigationTitle("Adjustments")
            .confirmationDialog("Reverse this adjustment today?", isPresented: $confirmReverse) {
                Button("Record opposite postings") {
                    guard let original = reversing else { return }
                    let reverse = JournalEntry(memo: String("Reversal: \(original.memo)".prefix(120)), date: .now, lines: original.lines.map { JournalLine(accountID: $0.accountID, debit: $0.credit, credit: $0.debit) })
                    do {
                        var books = plans.snapshot.books; books.journals.append(reverse)
                        let book = try AccountingBook(categories: categories.map(\.value), entries: entries.map(\.value), books: books)
                        try book.validateReconciliations(books.reconciliations)
                        try plans.update { $0.books = books }
                        message = "Reversal recorded. The original adjustment remains in your history."
                    } catch { message = "Couldn’t record the reversal. If today’s statement is checked, remove that check in Accounts first." }
                }
            }
    }
}
