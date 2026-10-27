import Foundation

public enum WorkspaceMode: String, Codable, Sendable {
    case personal, demo
    public var title: String { self == .demo ? "Sample workspace" : "My workspace" }
}

public enum BackupError: Error, LocalizedError {
    case invalid
    public var errorDescription: String? {
        "This is not a supported Nest backup. Your existing data has not been changed."
    }
}

/// Portable, versioned backup. Money remains integer AUD cents throughout.
public struct WorkspaceBackup: Codable, Equatable, Sendable {
    public let version: Int
    public let currency: String
    public var categories: [Category]
    public var entries: [Entry]
    public var planning: PlanningSnapshot
    public var sourceIDs: [String: String]
    public init(categories: [Category], entries: [Entry], planning: PlanningSnapshot, sourceIDs: [String: String] = [:]) {
        version = 1; currency = "AUD"
        self.categories = categories; self.entries = entries; self.planning = planning; self.sourceIDs = sourceIDs
    }
    private enum CodingKeys: String, CodingKey { case version, currency, categories, entries, planning, sourceIDs }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        currency = try values.decode(String.self, forKey: .currency)
        categories = try values.decode([Category].self, forKey: .categories)
        entries = try values.decode([Entry].self, forKey: .entries)
        planning = try values.decode(PlanningSnapshot.self, forKey: .planning)
        sourceIDs = try values.decodeIfPresent([String: String].self, forKey: .sourceIDs) ?? [:]
    }
    public func validate() throws {
        let limit: Int64 = 99_999_999_999
        func money(_ value: Int64) -> Bool { (0...limit).contains(value) }
        func name(_ value: String, limit: Int) -> Bool {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && value.count <= limit
        }
        func date(_ value: Date) -> Bool {
            value.timeIntervalSince1970.isFinite && (-2_208_988_800...4_133_980_800).contains(value.timeIntervalSince1970)
        }
        let categoryIDs = Set(categories.map(\.id))
        let entryIDs = Set(entries.map { $0.id.uuidString })
        guard Set(sourceIDs.keys).isSubset(of: entryIDs), Set(sourceIDs.values).count == sourceIDs.count,
              sourceIDs.values.allSatisfy({ $0.count <= 512 && ($0.hasPrefix("csv/") || $0.hasPrefix("nest-demo/")) }) else { throw BackupError.invalid }
        let budgetKeys = planning.books.budgets.map(\.key)
        guard planning.books.budgets.count <= 2400, Set(budgetKeys).count == budgetKeys.count,
              Set(planning.books.budgets.map(\.id)).count == planning.books.budgets.count,
              planning.books.budgets.allSatisfy({ categoryIDs.contains($0.categoryID) && (1900...2100).contains($0.year) && (1...12).contains($0.month) && $0.limit > 0 && money($0.limit) }) else { throw BackupError.invalid }
        let plan = planning.lifestyle
        let books = planning.books
        guard books.accounts.count <= 200, books.journals.count <= 10_000, books.reconciliations.count <= 1_000,
              books.accounts.allSatisfy({ name($0.name, limit: 60) && (!$0.isBank || $0.kind == .asset || $0.kind == .liability) }),
              books.journals.allSatisfy({ date($0.date) }),
              books.reconciliations.allSatisfy({ date($0.date) && $0.entryIDs.count <= 110_000 && (-1_000_000_000_000_000_000...1_000_000_000_000_000_000).contains($0.statementBalance) }) else { throw BackupError.invalid }
        do {
            let book = try AccountingBook(categories: categories, entries: entries, books: books)
            for reconciliation in books.reconciliations {
                let expected = try book.reconcile(accountID: reconciliation.accountID, through: reconciliation.date, statementBalance: reconciliation.statementBalance)
                guard Set(expected.entryIDs) == Set(reconciliation.entryIDs) else { throw BackupError.invalid }
            }
        } catch { throw BackupError.invalid }
        guard version == 1, currency == "AUD", !categories.isEmpty, categories.count <= 200,
              entries.count <= 100_000, categoryIDs.count == categories.count,
              Set(entries.map(\.id)).count == entries.count,
              categories.allSatisfy({ name($0.name, limit: 30) && !$0.symbol.isEmpty && !$0.colour.isEmpty }),
              entries.allSatisfy({ money($0.cents) && $0.cents > 0 && name($0.merchant, limit: 80) && categoryIDs.contains($0.categoryID) && date($0.date) }),
              planning.goals.count <= 500, planning.debts.count <= 500,
              Set(planning.goals.map(\.id)).count == planning.goals.count,
              Set(planning.debts.map(\.id)).count == planning.debts.count,
              planning.goals.allSatisfy({ name($0.name, limit: 60) && money($0.target) && $0.target > 0 && money($0.saved) && date($0.deadline) }),
              planning.debts.allSatisfy({ name($0.name, limit: 60) && money($0.balance) && money($0.payment) && $0.payment > 0 && money($0.extra) && $0.annualRatePercent.isFinite && (0...100).contains($0.annualRatePercent) }),
              [plan.income, plan.monthlySpending, plan.flexibleSpending, plan.reserve, plan.otherCommitments].allSatisfy(money),
              plan.reductionPercent.isFinite, (0...30).contains(plan.reductionPercent),
              Set(plan.protectedCategories).isSubset(of: categoryIDs) else { throw BackupError.invalid }
    }
    public func encoded() throws -> Data {
        try validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        guard data.count <= 25_000_000 else { throw BackupError.invalid }
        return data
    }
    public static func decode(_ data: Data) throws -> WorkspaceBackup {
        guard data.count <= 25_000_000 else { throw BackupError.invalid }
        do {
            let backup = try JSONDecoder().decode(Self.self, from: data)
            try backup.validate()
            return backup
        } catch { throw BackupError.invalid }
    }
}
