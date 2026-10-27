import Foundation

public struct StatementRow: Sendable {
    public let sourceID: String
    public let entry: Entry
}
public enum StatementCSVError: Error, LocalizedError {
    case invalid(String)
    public var errorDescription: String? {
        switch self { case .invalid(let message): message }
    }
}
public enum StatementCSV {
    public static let header = ["id", "date", "description", "amount", "type", "category", "account", "to_account"]
    public static let template = "id,date,description,amount,type,category,account,to_account\r\nexample-1,2026-10-01,Weekly groceries,85.50,expense,Groceries,Everyday account,\r\n"

    /// A documented CSV contract rather than guessing ambiguous bank formats.
    /// IDs must remain stable in subsequent exports from the same account.
    public static func parse(_ data: Data, categories: [Category], accounts: [LedgerAccount], now: Date = .now, calendar: Calendar = .current) throws -> [StatementRow] {
        guard data.count <= 10_000_000, var text = String(data: data, encoding: .utf8) else { throw StatementCSVError.invalid("Choose a UTF-8 CSV smaller than 10 MB.") }
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        let rows = try fields(text)
        guard let first = rows.first, first.map({ $0.trimmingCharacters(in: .whitespaces).lowercased() }) == header else {
            throw StatementCSVError.invalid("Use these CSV columns in order: \(header.joined(separator: ", ")).")
        }
        guard rows.count > 1, rows.count <= 10_001 else { throw StatementCSVError.invalid("Import between 1 and 10,000 transactions at a time.") }
        var result: [StatementRow] = []
        var seen = Set<String>()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone; formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
        for (index, row) in rows.dropFirst().enumerated() {
            let line = index + 2
            guard row.count == header.count else { throw StatementCSVError.invalid("Row \(line) needs exactly eight columns.") }
            let value = row.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard !value[0].isEmpty, value[0].count <= 120, !value[2].isEmpty, value[2].count <= 80,
                  value[1].range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil,
                  let date = formatter.date(from: value[1]), formatter.string(from: date) == value[1], date <= now,
                  let cents = Money.parse(value[3]), let kind = EntryKind(rawValue: value[4].lowercased()),
                  let category = categories.first(where: { $0.name.localizedCaseInsensitiveCompare(value[5]) == .orderedSame }),
                  let account = accounts.first(where: { $0.isBank && $0.name.localizedCaseInsensitiveCompare(value[6]) == .orderedSame })
            else { throw StatementCSVError.invalid("Check row \(line): use a stable ID, YYYY-MM-DD date, positive AUD amount, expense/income/transfer type, and existing category and account names. Future dates are not accepted.") }
            var destination: UUID?
            if kind == .transfer {
                guard let target = accounts.first(where: { $0.isBank && $0.id != account.id && $0.name.localizedCaseInsensitiveCompare(value[7]) == .orderedSame }) else {
                    throw StatementCSVError.invalid("Row \(line) needs a different existing destination account for its transfer.")
                }
                destination = target.id
            } else if !value[7].isEmpty { throw StatementCSVError.invalid("Row \(line): to_account must be empty unless the type is transfer.") }
            let source = "csv/\(account.id.uuidString)/\(value[0])"
            guard seen.insert(source).inserted else { throw StatementCSVError.invalid("Row \(line) repeats an ID for the same account.") }
            result.append(StatementRow(sourceID: source, entry: Entry(merchant: value[2], cents: cents, date: date, kind: kind, categoryID: category.id, accountID: account.id, transferAccountID: destination)))
        }
        return result
    }
    private static func fields(_ text: String) throws -> [[String]] {
        var rows: [[String]] = [], row: [String] = [], field = ""
        var quoted = false, closed = false
        let chars = Array(text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n"))
        var index = 0
        while index < chars.count {
            let char = chars[index]
            if quoted {
                if char == "\"" {
                    if index + 1 < chars.count, chars[index + 1] == "\"" { field.append("\""); index += 1 }
                    else { quoted = false; closed = true }
                } else { field.append(char) }
            } else if char == "," { row.append(field); field = ""; closed = false }
            else if char == "\n" {
                row.append(field)
                if !row.allSatisfy(\.isEmpty) { rows.append(row) }
                row = []; field = ""; closed = false
            } else if char == "\"", field.isEmpty, !closed { quoted = true }
            else {
                guard !closed, char != "\"" else { throw StatementCSVError.invalid("The CSV contains a malformed quoted field.") }
                field.append(char)
            }
            index += 1
        }
        guard !quoted else { throw StatementCSVError.invalid("The CSV has an unfinished quoted field.") }
        if !field.isEmpty || !row.isEmpty || closed { row.append(field); rows.append(row) }
        return rows
    }
}
