import Foundation
import SwiftData
import NestCore

@Model final class CategoryRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var symbol: String
    var colour: String
    init(_ category: NestCore.Category) {
        id = category.id; name = category.name; symbol = category.symbol; colour = category.colour
    }
    var value: NestCore.Category { NestCore.Category(id: id, name: name, symbol: symbol, colour: colour) }
}

@Model final class TransactionRecord {
    @Attribute(.unique) var id: UUID
    var merchant: String
    var cents: Int64
    var date: Date
    var kindRaw: String
    var categoryID: UUID
    var pending: Bool
    var accountID: UUID? = nil
    var transferAccountID: UUID? = nil
    @Attribute(.unique) var providerID: String? = nil
    init(_ entry: Entry) {
        id = entry.id; merchant = entry.merchant; cents = entry.cents; date = entry.date
        kindRaw = entry.kind.rawValue; categoryID = entry.categoryID; pending = entry.pending
        accountID = entry.accountID; transferAccountID = entry.transferAccountID
    }
    var value: Entry {
        Entry(id: id, merchant: merchant, cents: cents, date: date,
              kind: EntryKind(rawValue: kindRaw) ?? .expense, categoryID: categoryID, pending: pending, accountID: accountID, transferAccountID: transferAccountID)
    }
}

@Model final class SeedRecord {
    @Attribute(.unique) var key: String
    init(key: String) { self.key = key }
}

@Model final class PlanningRecord {
    @Attribute(.unique) var key: String
    var payload: Data
    init(payload: Data) { key = "planning-v1"; self.payload = payload }
}

@MainActor public enum NestPersistence {
    public static func makeContainer(inMemory: Bool = false, mode: WorkspaceMode = .demo, storeURL: URL? = nil) throws -> ModelContainer {
        let schema = Schema([CategoryRecord.self, TransactionRecord.self, SeedRecord.self, PlanningRecord.self])
        let name = mode == .demo ? "NestDemo" : "NestPersonal"
        let config: ModelConfiguration
        if let storeURL {
            config = ModelConfiguration(name, schema: schema, url: storeURL, cloudKitDatabase: .none)
        } else {
            config = ModelConfiguration(name, schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        }
        let container = try ModelContainer(for: schema, configurations: config)
        let context = container.mainContext
        context.autosaveEnabled = false
        if try context.fetchCount(FetchDescriptor<SeedRecord>()) == 0 {
            let sample = SampleData.make()
            sample.categories.forEach { context.insert(CategoryRecord($0)) }
            if mode == .demo { sample.entries.forEach { context.insert(TransactionRecord($0)) } }
            context.insert(SeedRecord(key: "demo-v1"))
            try context.save()
        }
        return container
    }
}
