import Testing
import Foundation
@testable import NestCore

private func fixture() -> WorkspaceBackup {
    let sample = SampleData.make()
    var plans = PlanningSnapshot()
    plans.goals = [SavingsGoal(name: "Holiday", kind: .holiday, target: 200000, saved: 25000, deadline: .now)]
    plans.debts = [Debt(name: "Loan", balance: 200000, annualRatePercent: 6, payment: 10000, extra: 1000)]
    plans.lifestyle.protectedCategories = [sample.categories[0].id]
    return WorkspaceBackup(categories: sample.categories, entries: sample.entries, planning: plans)
}

@Test func backupRoundTripsEveryMoneyRecord() throws {
    let backup = fixture()
    let decoded = try WorkspaceBackup.decode(backup.encoded())
    #expect(decoded == backup)
}
@Test func backupRejectsDuplicateAndDanglingRecords() throws {
    var backup = fixture()
    backup.entries.append(backup.entries[0])
    #expect(throws: BackupError.self) { try backup.validate() }
    backup = fixture()
    backup.entries[0].categoryID = UUID()
    #expect(throws: BackupError.self) { try backup.validate() }
    backup = fixture()
    backup.categories.append(backup.categories[0])
    #expect(throws: BackupError.self) { try backup.validate() }
}
@Test func backupRejectsInvalidFinancialValues() {
    var backup = fixture()
    backup.entries[0].cents = -1
    #expect(throws: BackupError.self) { try backup.validate() }
    backup = fixture()
    backup.planning.debts[0].annualRatePercent = .infinity
    #expect(throws: BackupError.self) { try backup.validate() }
    backup = fixture()
    backup.planning.goals[0].target = 0
    #expect(throws: BackupError.self) { try backup.validate() }
    backup = fixture()
    backup.planning.lifestyle.protectedCategories = [UUID()]
    #expect(throws: BackupError.self) { try backup.validate() }
}
@Test func backupRejectsUnknownVersionsCurrenciesAndMalformedFiles() throws {
    let data = try fixture().encoded()
    var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    object["version"] = 99
    #expect(throws: BackupError.self) { try WorkspaceBackup.decode(JSONSerialization.data(withJSONObject: object)) }
    object["version"] = 1
    object["currency"] = "USD"
    #expect(throws: BackupError.self) { try WorkspaceBackup.decode(JSONSerialization.data(withJSONObject: object)) }
    #expect(throws: BackupError.self) { try WorkspaceBackup.decode(Data("{broken".utf8)) }
    #expect(throws: BackupError.self) { try WorkspaceBackup.decode(Data(repeating: 0, count: 25_000_001)) }
}

@Test func backupRetainsImportIDsAccountsBudgetsAndStatementChecks() throws {
    var backup = fixture()
    let entry = backup.entries[0]
    backup.sourceIDs[entry.id.uuidString] = "csv/source-1"
    backup.planning.books.budgets = [MonthlyBudget(categoryID: entry.categoryID, year: 2026, month: 10, limit: 50000)]
    let book = try AccountingBook(categories: backup.categories, entries: backup.entries, books: backup.planning.books)
    let end = Date.distantFuture
    // A realistic cutoff within the supported backup date range.
    let date = min(end, Date(timeIntervalSince1970: 4_102_444_800))
    backup.planning.books.reconciliations = [try book.reconcile(accountID: ChartOfAccounts.bankID, through: date, statementBalance: book.balance(accountID: ChartOfAccounts.bankID, through: date))]
    let decoded = try WorkspaceBackup.decode(backup.encoded())
    #expect(decoded == backup)
    #expect(decoded.sourceIDs[entry.id.uuidString] == "csv/source-1")
}
@Test func duplicateMonthlyBudgetsAndImportIDsAreRejected() {
    var backup = fixture()
    let budget = MonthlyBudget(categoryID: backup.categories[0].id, year: 2026, month: 10, limit: 10000)
    backup.planning.books.budgets = [budget, budget]
    #expect(throws: BackupError.self) { try backup.validate() }
    backup = fixture()
    backup.sourceIDs = [backup.entries[0].id.uuidString: "csv/same", backup.entries[1].id.uuidString: "csv/same"]
    #expect(throws: BackupError.self) { try backup.validate() }
}
@Test func originalPlanningSnapshotsAndBackupsRemainReadable() throws {
    let backup = fixture()
    var object = try #require(JSONSerialization.jsonObject(with: backup.encoded()) as? [String: Any])
    object.removeValue(forKey: "sourceIDs")
    var plan = try #require(object["planning"] as? [String: Any])
    plan.removeValue(forKey: "books")
    object["planning"] = plan
    let decoded = try WorkspaceBackup.decode(JSONSerialization.data(withJSONObject: object))
    #expect(decoded.sourceIDs.isEmpty)
    #expect(decoded.planning.books == BookkeepingSnapshot())
    #expect(decoded.entries == backup.entries)
}
