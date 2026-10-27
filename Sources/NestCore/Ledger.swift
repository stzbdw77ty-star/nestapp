import Foundation

public enum EntryKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case expense, income, transfer
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public struct Category: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var symbol: String
    public var colour: String
    public init(id: UUID = UUID(), name: String, symbol: String, colour: String) {
        self.id = id; self.name = name; self.symbol = symbol; self.colour = colour
    }
}

public struct Entry: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var merchant: String
    /// Positive AUD minor units. Direction is expressed by kind, never by a float.
    public var cents: Int64
    public var date: Date
    public var kind: EntryKind
    public var categoryID: UUID
    public var pending: Bool
    public var accountID: UUID?
    public var transferAccountID: UUID?
    public init(id: UUID = UUID(), merchant: String, cents: Int64, date: Date,
                kind: EntryKind, categoryID: UUID, pending: Bool = false, accountID: UUID? = nil, transferAccountID: UUID? = nil) {
        self.id = id; self.merchant = merchant; self.cents = cents; self.date = date
        self.kind = kind; self.categoryID = categoryID; self.pending = pending
        self.accountID = accountID; self.transferAccountID = transferAccountID
    }
}

public enum Money {
    public static func text(_ cents: Int64) -> String {
        (Decimal(cents) / 100).formatted(.currency(code: "AUD").locale(Locale(identifier: "en_AU")))
    }

    /// Deliberately accepts only ungrouped AUD values, e.g. 12 or 12.50.
    public static func parse(_ text: String) -> Int64? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.range(of: #"^[0-9]{1,9}(\.[0-9]{1,2})?$"#, options: .regularExpression) != nil else { return nil }
        let pieces = value.split(separator: ".")
        guard let dollars = Int64(pieces[0]) else { return nil }
        let fractional = pieces.count == 2 ? String(pieces[1]) : ""
        let cents = Int64(fractional.padding(toLength: 2, withPad: "0", startingAt: 0)) ?? 0
        let result = dollars * 100 + cents
        return result > 0 ? result : nil
    }
}

public struct CategoryTotal: Identifiable, Equatable, Sendable {
    public var id: UUID { category.id }
    public let category: Category
    public let cents: Int64
}

public enum Ledger {
    /// Half-open date boundaries prevent counting midnight in both months.
    public static func entries(_ entries: [Entry], month: Date, calendar: Calendar = .current) -> [Entry] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        return entries.filter { $0.date >= interval.start && $0.date < interval.end }
            .sorted { $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date > $1.date }
    }
    public static func total(_ entries: [Entry], kind: EntryKind) -> Int64 {
        entries.filter { $0.kind == kind && !$0.pending }.reduce(0) { $0 + $1.cents }
    }
    public static func spending(_ entries: [Entry], categories: [Category]) -> [CategoryTotal] {
        categories.map { category in
            CategoryTotal(category: category, cents: total(entries.filter { $0.categoryID == category.id }, kind: .expense))
        }.filter { $0.cents > 0 }.sorted {
            $0.cents == $1.cents ? $0.id.uuidString < $1.id.uuidString : $0.cents > $1.cents
        }
    }
    public static func validCategoryName(_ name: String, excluding id: UUID?, categories: [Category]) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 30 && !categories.contains {
            $0.id != id && $0.name.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }
}
