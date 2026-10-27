import Testing
import Foundation
@testable import NestCore

private func accountingFixture() throws -> AccountingBook {
    let category = Category(name: "Office expenses", symbol: "tag", colour: "mint")
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let transactions = [
        Entry(merchant: "Client payment", cents: 100000, date: now, kind: .income, categoryID: category.id),
        Entry(merchant: "Supplies", cents: 20000, date: now, kind: .expense, categoryID: category.id),
        Entry(merchant: "Savings", cents: 30000, date: now, kind: .transfer, categoryID: category.id),
        Entry(merchant: "Pending", cents: 9999, date: now, kind: .expense, categoryID: category.id, pending: true)
    ]
    var books = BookkeepingSnapshot()
    books.journals = [JournalEntry(memo: "Opening capital", date: now.addingTimeInterval(-86400), lines: [
        .init(accountID: ChartOfAccounts.bankID, debit: 50000),
        .init(accountID: ChartOfAccounts.capitalID, credit: 50000)
    ])]
    return try AccountingBook(categories: [category], entries: transactions, books: books)
}
@Test func doubleEntryBalancesAndTransfersDoNotCreateProfit() throws {
    let book = try accountingFixture()
    let end = Date(timeIntervalSince1970: 1_800_000_001)
    let rows = book.trialBalance(through: end)
    #expect(rows.reduce(0) { $0 + $1.debit } == rows.reduce(0) { $0 + $1.credit })
    #expect(book.balance(accountID: ChartOfAccounts.bankID, through: end) == 100000)
    #expect(book.balance(accountID: ChartOfAccounts.savingsID, through: end) == 30000)
    #expect(book.profit(from: end.addingTimeInterval(-1), through: end) == 80000)
    let assets = rows.filter { $0.account.kind == .asset }.reduce(0) { $0 + $1.normalBalance }
    let liabilitiesAndEquity = rows.filter { $0.account.kind == .liability || $0.account.kind == .equity }.reduce(0) { $0 + $1.normalBalance }
    #expect(assets == liabilitiesAndEquity + book.profit(from: .distantPast, through: end))
    #expect(book.journals.count == 4)
}
@Test func unbalancedAndUnknownAccountJournalsAreRejected() {
    let journal = JournalEntry(memo: "Broken", date: .now, lines: [
        .init(accountID: ChartOfAccounts.bankID, debit: 100), .init(accountID: ChartOfAccounts.incomeID, credit: 99)
    ])
    #expect(throws: AccountingError.self) { try journal.validate(accounts: ChartOfAccounts.defaults) }
    let unknown = JournalEntry(memo: "Unknown", date: .now, lines: [
        .init(accountID: UUID(), debit: 100), .init(accountID: ChartOfAccounts.incomeID, credit: 100)
    ])
    #expect(throws: AccountingError.self) { try unknown.validate(accounts: ChartOfAccounts.defaults) }
}
@Test func creditCardAndLoanEntriesUseCorrectNormalBalances() throws {
    var books = BookkeepingSnapshot()
    books.journals = [JournalEntry(memo: "Loan proceeds", date: .now, lines: [
        .init(accountID: ChartOfAccounts.bankID, debit: 100000), .init(accountID: ChartOfAccounts.payableID, credit: 100000)
    ])]
    let book = try AccountingBook(categories: [], entries: [], books: books)
    #expect(book.balance(accountID: ChartOfAccounts.bankID, through: .distantFuture) == 100000)
    #expect(book.balance(accountID: ChartOfAccounts.payableID, through: .distantFuture) == 100000)
    #expect(book.profit(from: .distantPast, through: .distantFuture) == 0)
}
@Test func reconciliationRequiresExactStatementBalanceAndLocksSourceEntries() throws {
    let book = try accountingFixture()
    let end = Date(timeIntervalSince1970: 1_800_000_001)
    #expect(throws: AccountingError.self) { try book.reconcile(accountID: ChartOfAccounts.bankID, through: end, statementBalance: 99999) }
    let reconciliation = try book.reconcile(accountID: ChartOfAccounts.bankID, through: end, statementBalance: 100000)
    #expect(reconciliation.entryIDs.count == 4)
    var snapshot = BookkeepingSnapshot()
    snapshot.reconciliations = [reconciliation]
    #expect(snapshot.lockedEntryIDs == Set(book.journals.map(\.id)))
}
@Test func CSVPreservesCentsAndNeutralisesSpreadsheetFormulae() throws {
    var books = BookkeepingSnapshot()
    books.journals = [JournalEntry(memo: "=SUM(1,2)", date: .now, lines: [
        .init(accountID: ChartOfAccounts.bankID, debit: 12345), .init(accountID: ChartOfAccounts.incomeID, credit: 12345)
    ])]
    let csv = try AccountingBook(categories: [], entries: [], books: books).journalCSV(through: .distantFuture)
    #expect(csv.contains("\"'=SUM(1,2)\""))
    #expect(csv.contains("123.45,0.00"))
    #expect(csv.contains("0.00,123.45"))
}

@Test func backdatedRecordsCannotSilentlyInvalidateAStatementCheck() throws {
    let original = try accountingFixture()
    let end = Date(timeIntervalSince1970: 1_800_000_001)
    let checked = try original.reconcile(accountID: ChartOfAccounts.bankID, through: end, statementBalance: 100000)
    let category = Category(name: "Food", symbol: "tag", colour: "mint")
    var books = BookkeepingSnapshot()
    books.journals = original.journals + [JournalEntry(memo: "Backdated missing item", date: end.addingTimeInterval(-1), lines: [
        .init(accountID: ChartOfAccounts.bankID, debit: 100), .init(accountID: ChartOfAccounts.incomeID, credit: 100)
    ])]
    // Use all original category accounts to retain the projected expense postings.
    books.accounts = original.accounts.filter { !ChartOfAccounts.defaults.map(\.id).contains($0.id) }
    let changed = try AccountingBook(categories: [category], entries: [], books: books)
    #expect(throws: AccountingError.self) { try changed.validateReconciliations([checked]) }
}
