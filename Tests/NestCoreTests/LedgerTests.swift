import Testing
import Foundation
@testable import NestCore

@Test func currencyParsingIsExactAndRejectsAmbiguity() {
    #expect(Money.parse("0.01") == 1)
    #expect(Money.parse("12.5") == 1250)
    #expect(Money.parse(" 123.45 ") == 12345)
    for value in ["-12", "0", "0.00", "1.234", "1,234", "12x", "NaN", "1e3", "1000000000"] {
        #expect(Money.parse(value) == nil)
    }
}

@Test func cashflowExcludesTransfersAndPending() {
    let category = Category(name: "Food", symbol: "carrot", colour: "mint")
    let entries = [
        Entry(merchant: "Pay", cents: 100000, date: .now, kind: .income, categoryID: category.id),
        Entry(merchant: "Food", cents: 2099, date: .now, kind: .expense, categoryID: category.id),
        Entry(merchant: "Pending", cents: 5000, date: .now, kind: .expense, categoryID: category.id, pending: true),
        Entry(merchant: "Transfer", cents: 30000, date: .now, kind: .transfer, categoryID: category.id)
    ]
    #expect(Ledger.total(entries, kind: .income) == 100000)
    #expect(Ledger.total(entries, kind: .expense) == 2099)
    #expect(Ledger.spending(entries, categories: [category]).first?.cents == 2099)
}

@Test func renamedCategoriesRetainTransactions() {
    var category = Category(name: "Food", symbol: "carrot", colour: "mint")
    let entry = Entry(merchant: "Market", cents: 2590, date: .now, kind: .expense, categoryID: category.id)
    category.name = "Groceries"
    let result = Ledger.spending([entry], categories: [category])
    #expect(result.first?.category.name == "Groceries")
    #expect(result.first?.cents == 2590)
    #expect(!Ledger.validCategoryName(" groceries ", excluding: nil, categories: [category]))
    #expect(!Ledger.validCategoryName("  ", excluding: nil, categories: [category]))
    #expect(Ledger.validCategoryName("Groceries", excluding: category.id, categories: [category]))
}

@Test func monthBoundariesRespectSydneyTime() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Australia/Sydney")!
    let october = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!
    let november = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1))!
    let categoryID = UUID()
    let entries = [october.addingTimeInterval(-1), october, november.addingTimeInterval(-1), november].map {
        Entry(merchant: "Boundary", cents: 100, date: $0, kind: .expense, categoryID: categoryID)
    }
    #expect(Ledger.entries(entries, month: october, calendar: calendar).count == 2)
}

@Test func sampleDataIsConsistentAndNotFutureDated() {
    let sample = SampleData.make()
    let ids = Set(sample.categories.map(\.id))
    #expect(sample.entries.allSatisfy { ids.contains($0.categoryID) && $0.date <= .now && $0.cents > 0 })
    #expect(Ledger.total(sample.entries, kind: .expense) == 159419)
}
