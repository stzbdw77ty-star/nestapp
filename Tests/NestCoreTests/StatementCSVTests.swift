import Testing
import Foundation
@testable import NestCore

@Test func statementCSVParsesQuotedMerchantsAndExactCents() throws {
    let sample = SampleData.make()
    let csv = StatementCSV.header.joined(separator: ",") + "\r\nx1,2026-10-01,\"Cafe, \"\"Sunday\"\"\",12.05,expense,Groceries,Everyday account,\r\n"
    let rows = try StatementCSV.parse(Data(csv.utf8), categories: sample.categories, accounts: ChartOfAccounts.defaults, now: .distantFuture)
    #expect(rows.count == 1)
    #expect(rows.first?.entry.merchant == "Cafe, \"Sunday\"")
    #expect(rows.first?.entry.cents == 1205)
}
@Test func statementImportIDsAreStableAndScopedToAccount() throws {
    let sample = SampleData.make()
    let first = try StatementCSV.parse(Data(StatementCSV.template.utf8), categories: sample.categories, accounts: ChartOfAccounts.defaults, now: .distantFuture)
    let second = try StatementCSV.parse(Data(StatementCSV.template.utf8), categories: sample.categories, accounts: ChartOfAccounts.defaults, now: .distantFuture)
    #expect(first[0].sourceID == second[0].sourceID)
}
@Test func statementCSVRejectsAmbiguousMoneyMissingAccountsAndInvalidTransfers() {
    let sample = SampleData.make()
    for row in [
        "x,2026-10-01,Food,-10,expense,Groceries,Everyday account,",
        "x,2026-10-01,Food,10.001,expense,Groceries,Everyday account,",
        "x,2026-02-30,Food,10,expense,Groceries,Everyday account,",
        "x,2026-10-01,Food,10,expense,Unknown,Everyday account,",
        "x,2026-10-01,Food,10,transfer,Transfers,Everyday account,Everyday account",
        "x,2026-10-01,Food,10,income,Income,Missing account,"
    ] {
        let data = Data((StatementCSV.header.joined(separator: ",") + "\n" + row + "\n").utf8)
        #expect(throws: StatementCSVError.self) { try StatementCSV.parse(data, categories: sample.categories, accounts: ChartOfAccounts.defaults, now: .distantFuture) }
    }
}
@Test func statementCSVRejectsDuplicateSourceIDsAndMalformedQuotes() {
    let sample = SampleData.make()
    let row = "x,2026-10-01,Food,10,expense,Groceries,Everyday account,\n"
    let data = Data((StatementCSV.header.joined(separator: ",") + "\n" + row + row).utf8)
    #expect(throws: StatementCSVError.self) { try StatementCSV.parse(data, categories: sample.categories, accounts: ChartOfAccounts.defaults, now: .distantFuture) }
    #expect(throws: StatementCSVError.self) { try StatementCSV.parse(Data((StatementCSV.header.joined(separator: ",") + "\n\"unfinished").utf8), categories: sample.categories, accounts: ChartOfAccounts.defaults) }
}
