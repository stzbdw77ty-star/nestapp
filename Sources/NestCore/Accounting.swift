import Foundation

public enum AccountKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case asset, liability, equity, income, expense
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public var debitNormal: Bool { self == .asset || self == .expense }
}
public struct LedgerAccount: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var kind: AccountKind
    public var isBank: Bool
    public init(id: UUID = UUID(), name: String, kind: AccountKind, isBank: Bool = false) {
        self.id = id; self.name = name; self.kind = kind; self.isBank = isBank
    }
}
public enum ChartOfAccounts {
    public static let bankID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    public static let savingsID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
    public static let payableID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
    public static let cardID = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
    public static let capitalID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
    public static let incomeID = UUID(uuidString: "40000000-0000-0000-0000-000000000001")!
    public static let defaults: [LedgerAccount] = [
        .init(id: bankID, name: "Everyday account", kind: .asset, isBank: true),
        .init(id: savingsID, name: "Savings account", kind: .asset, isBank: true),
        .init(id: payableID, name: "Loans payable", kind: .liability),
        .init(id: cardID, name: "Credit card", kind: .liability, isBank: true),
        .init(id: capitalID, name: "Owner contributions / opening equity", kind: .equity),
        .init(id: incomeID, name: "Income", kind: .income)
    ]
    public static func accounts(categories: [Category], custom: [LedgerAccount]) -> [LedgerAccount] {
        defaults + categories.map { LedgerAccount(id: $0.id, name: $0.name, kind: .expense) } + custom
    }
}
public struct JournalLine: Codable, Equatable, Sendable {
    public var accountID: UUID
    public var debit: Int64
    public var credit: Int64
    public init(accountID: UUID, debit: Int64 = 0, credit: Int64 = 0) {
        self.accountID = accountID; self.debit = debit; self.credit = credit
    }
}
public struct JournalEntry: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var memo: String
    public var date: Date
    public var lines: [JournalLine]
    public init(id: UUID = UUID(), memo: String, date: Date, lines: [JournalLine]) {
        self.id = id; self.memo = memo; self.date = date; self.lines = lines
    }
    public func validate(accounts: [LedgerAccount]) throws {
        let ids = Set(accounts.map(\.id))
        guard !memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, memo.count <= 120,
              date.timeIntervalSince1970.isFinite,
              (2...100).contains(lines.count),
              lines.allSatisfy({ ids.contains($0.accountID) && (0...99_999_999_999).contains($0.debit) && (0...99_999_999_999).contains($0.credit) && ($0.debit > 0) != ($0.credit > 0) }),
              lines.reduce(Int64(0), { $0 + $1.debit }) == lines.reduce(Int64(0), { $0 + $1.credit })
        else { throw AccountingError.invalidJournal }
    }
}
public enum AccountingError: Error, LocalizedError {
    case invalidJournal, invalidAccounts
    public var errorDescription: String? {
        switch self {
        case .invalidJournal: "Every journal needs a description, valid accounts and equal debit and credit totals."
        case .invalidAccounts: "Account names must be unique and every posting must reference an existing account."
        }
    }
}
public struct Reconciliation: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var accountID: UUID
    public var date: Date
    public var statementBalance: Int64
    public var entryIDs: [UUID]
    public init(accountID: UUID, date: Date, statementBalance: Int64, entryIDs: [UUID]) {
        id = UUID(); self.accountID = accountID; self.date = date
        self.statementBalance = statementBalance; self.entryIDs = entryIDs
    }
}
public struct MonthlyBudget: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var categoryID: UUID
    public var year: Int
    public var month: Int
    public var limit: Int64
    public init(id: UUID = UUID(), categoryID: UUID, year: Int, month: Int, limit: Int64) {
        self.id = id; self.categoryID = categoryID; self.year = year; self.month = month; self.limit = limit
    }
    public var key: String { "\(categoryID)-\(year)-\(month)" }
}
public struct BookkeepingSnapshot: Codable, Equatable, Sendable {
    public var accounts: [LedgerAccount] = []
    public var journals: [JournalEntry] = []
    public var reconciliations: [Reconciliation] = []
    public var budgets: [MonthlyBudget] = []
    public init() {}
    private enum CodingKeys: String, CodingKey { case accounts, journals, reconciliations, budgets }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        accounts = try values.decodeIfPresent([LedgerAccount].self, forKey: .accounts) ?? []
        journals = try values.decodeIfPresent([JournalEntry].self, forKey: .journals) ?? []
        reconciliations = try values.decodeIfPresent([Reconciliation].self, forKey: .reconciliations) ?? []
        budgets = try values.decodeIfPresent([MonthlyBudget].self, forKey: .budgets) ?? []
    }
    public var lockedEntryIDs: Set<UUID> { Set(reconciliations.flatMap(\.entryIDs)) }
}
public struct TrialBalanceRow: Identifiable, Sendable {
    public var id: UUID { account.id }
    public let account: LedgerAccount
    /// Raw balance, debit minus credit. Assets/expenses usually positive.
    public let netDebit: Int64
    public var debit: Int64 { max(0, netDebit) }
    public var credit: Int64 { max(0, -netDebit) }
    public var normalBalance: Int64 { account.kind.debitNormal ? netDebit : -netDebit }
}
public struct AccountingBook: Sendable {
    public let accounts: [LedgerAccount]
    public let journals: [JournalEntry]
    public init(categories: [Category], entries: [Entry], books: BookkeepingSnapshot) throws {
        accounts = ChartOfAccounts.accounts(categories: categories, custom: books.accounts)
        guard Set(accounts.map(\.id)).count == accounts.count else { throw AccountingError.invalidAccounts }
        let bankIDs = Set(accounts.filter(\.isBank).map(\.id))
        var projected: [JournalEntry] = []
        for entry in entries where !entry.pending {
            let bank = entry.accountID ?? ChartOfAccounts.bankID
            guard bankIDs.contains(bank), entry.cents > 0, entry.cents <= 99_999_999_999 else { throw AccountingError.invalidAccounts }
            let debit: UUID
            let credit: UUID
            switch entry.kind {
            case .income: debit = bank; credit = ChartOfAccounts.incomeID
            case .expense: debit = entry.categoryID; credit = bank
            case .transfer:
                debit = entry.transferAccountID ?? ChartOfAccounts.savingsID; credit = bank
                guard bankIDs.contains(debit), debit != credit else { throw AccountingError.invalidAccounts }
            }
            projected.append(JournalEntry(id: entry.id, memo: entry.merchant, date: entry.date, lines: [
                JournalLine(accountID: debit, debit: entry.cents), JournalLine(accountID: credit, credit: entry.cents)
            ]))
        }
        journals = (projected + books.journals).sorted { $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date > $1.date }
        guard Set(journals.map(\.id)).count == journals.count else { throw AccountingError.invalidJournal }
        for entry in journals { try entry.validate(accounts: accounts) }
    }
    public func trialBalance(through end: Date, since start: Date? = nil) -> [TrialBalanceRow] {
        var totals: [UUID: Int64] = [:]
        for entry in journals where entry.date <= end && (start == nil || entry.date >= start!) {
            for line in entry.lines { totals[line.accountID, default: 0] += line.debit - line.credit }
        }
        return accounts.map { TrialBalanceRow(account: $0, netDebit: totals[$0.id, default: 0]) }
    }
    public func balance(accountID: UUID, through date: Date = .now) -> Int64 {
        trialBalance(through: date).first { $0.id == accountID }?.normalBalance ?? 0
    }
    public func profit(from start: Date, through end: Date) -> Int64 {
        trialBalance(through: end, since: start).reduce(0) { result, row in
            switch row.account.kind {
            case .income: result + row.normalBalance
            case .expense: result - row.normalBalance
            default: result
            }
        }
    }
    /// Reconcile the complete posted ledger up to an end-of-day cutoff.
    /// Unmatched items must be corrected or entered before completing this check.
    public func reconcile(accountID: UUID, through date: Date, statementBalance: Int64) throws -> Reconciliation {
        guard accounts.contains(where: { $0.id == accountID && $0.isBank }), balance(accountID: accountID, through: date) == statementBalance else {
            throw AccountingError.invalidAccounts
        }
        let ids = journals.filter { $0.date <= date && $0.lines.contains { $0.accountID == accountID } }.map(\.id)
        return Reconciliation(accountID: accountID, date: date, statementBalance: statementBalance, entryIDs: ids)
    }
    public func validateReconciliations(_ items: [Reconciliation]) throws {
        for item in items {
            let expected = try reconcile(accountID: item.accountID, through: item.date, statementBalance: item.statementBalance)
            guard Set(expected.entryIDs) == Set(item.entryIDs) else { throw AccountingError.invalidAccounts }
        }
    }
    public func journalCSV(from start: Date? = nil, through date: Date = .now) -> String {
        func quote(_ text: String) -> String {
            // Keep spreadsheet applications from evaluating user-entered descriptions.
            let safe = ["=", "+", "-", "@", "\t", "\r", "\n"].contains(where: text.hasPrefix) ? "'" + text : text
            return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        let formatter = ISO8601DateFormatter()
        var rows = ["Entry ID,Date,Description,Account,Type,Debit AUD,Credit AUD"]
        for entry in journals.reversed() where entry.date <= date && (start == nil || entry.date >= start!) {
            for line in entry.lines {
                guard let account = accounts.first(where: { $0.id == line.accountID }) else { continue }
                func amount(_ cents: Int64) -> String { "\(cents / 100)." + String(format: "%02lld", cents % 100) }
                rows.append([entry.id.uuidString, formatter.string(from: entry.date), quote(entry.memo), quote(account.name), account.kind.rawValue, amount(line.debit), amount(line.credit)].joined(separator: ","))
            }
        }
        return rows.joined(separator: "\r\n") + "\r\n"
    }
}
