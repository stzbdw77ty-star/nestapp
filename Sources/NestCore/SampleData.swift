import Foundation

public enum SampleData {
    public static func make(now: Date = .now, calendar: Calendar = .current) -> (categories: [Category], entries: [Entry]) {
        let categories = [
            Category(name: "Groceries", symbol: "carrot.fill", colour: "mint"),
            Category(name: "Eating out", symbol: "fork.knife", colour: "peach"),
            Category(name: "Transport", symbol: "tram.fill", colour: "lilac"),
            Category(name: "Home & bills", symbol: "house.fill", colour: "blue"),
            Category(name: "Little joys", symbol: "sparkles", colour: "pink"),
            Category(name: "Income", symbol: "sun.max.fill", colour: "yellow"),
            Category(name: "Transfers", symbol: "arrow.left.arrow.right", colour: "blue")
        ]
        let start = calendar.dateInterval(of: .month, for: now)!.start
        let day = calendar.component(.day, from: now)
        func date(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: max(0, day - offset - 1), to: start)!
        }
        let rows: [(String, Int64, Int, EntryKind, Int, Bool)] = [
            ("Neighbourhood café", 1850, 0, .expense, 1, false),
            ("Fresh market", 8640, 1, .expense, 0, false),
            ("Opal top-up", 4000, 2, .expense, 2, false),
            ("Friday noodles", 3250, 3, .expense, 1, false),
            ("A good book", 2499, 4, .expense, 4, false),
            ("Weekly groceries", 11280, 5, .expense, 0, false),
            ("Internet", 7900, 6, .expense, 3, false),
            ("Pay day", 320000, 7, .income, 5, false),
            ("Rent", 120000, 8, .expense, 3, false),
            ("Savings transfer", 30000, 9, .transfer, 6, false),
            ("Weekend brunch", 2800, 0, .expense, 1, true)
        ]
        return (categories, rows.map {
            Entry(merchant: $0.0, cents: $0.1, date: date($0.2), kind: $0.3, categoryID: categories[$0.4].id, pending: $0.5)
        })
    }
}
