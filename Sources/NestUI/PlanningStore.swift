import Foundation
import Observation
import SwiftData
import NestCore

/// Planning and ledger changes now share one transactional SwiftData store.
@MainActor @Observable final class PlanningStore {
    private(set) var snapshot: PlanningSnapshot
    private let context: ModelContext
    private let record: PlanningRecord
    init(context: ModelContext, mode: WorkspaceMode, inMemory: Bool = false) throws {
        self.context = context
        if let record = try context.fetch(FetchDescriptor<PlanningRecord>()).first {
            self.record = record
            snapshot = try JSONDecoder().decode(PlanningSnapshot.self, from: record.payload)
        } else {
            var initial = PlanningSnapshot()
            // Preserve plans from the supplied prototype; never remove the legacy file.
            if mode == .demo, !inMemory,
               let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let legacy = folder.appendingPathComponent("NestDemo/planning-v1.json")
                if FileManager.default.fileExists(atPath: legacy.path) {
                    initial = try JSONDecoder().decode(PlanningSnapshot.self, from: Data(contentsOf: legacy))
                }
            }
            snapshot = initial
            record = PlanningRecord(payload: try JSONEncoder().encode(initial))
            context.insert(record)
            try context.save()
        }
    }
    func update(_ change: (inout PlanningSnapshot) -> Void) throws {
        var next = snapshot
        change(&next)
        do {
            record.payload = try JSONEncoder().encode(next)
            try context.save()
            snapshot = next
        } catch { context.rollback(); throw error }
    }
    func restore(_ backup: WorkspaceBackup) throws {
        try backup.validate()
        do {
            let categories = try context.fetch(FetchDescriptor<CategoryRecord>())
            let entries = try context.fetch(FetchDescriptor<TransactionRecord>())
            let categoryIDs = Set(backup.categories.map(\.id))
            let entryIDs = Set(backup.entries.map(\.id))
            categories.filter { !categoryIDs.contains($0.id) }.forEach { context.delete($0) }
            entries.filter { !entryIDs.contains($0.id) }.forEach { context.delete($0) }
            let categoryLookup = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
            let entryLookup = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
            for category in backup.categories {
                if let existing = categoryLookup[category.id] {
                    existing.name = category.name; existing.colour = category.colour; existing.symbol = category.symbol
                } else { context.insert(CategoryRecord(category)) }
            }
            for entry in backup.entries {
                if let existing = entryLookup[entry.id] {
                    existing.merchant = entry.merchant; existing.cents = entry.cents; existing.date = entry.date
                    existing.kindRaw = entry.kind.rawValue; existing.categoryID = entry.categoryID
                    existing.pending = entry.pending; existing.providerID = backup.sourceIDs[entry.id.uuidString]
                    existing.accountID = entry.accountID; existing.transferAccountID = entry.transferAccountID
                } else {
                    let record = TransactionRecord(entry)
                    record.providerID = backup.sourceIDs[entry.id.uuidString]
                    context.insert(record)
                }
            }
            record.payload = try JSONEncoder().encode(backup.planning)
            try context.save()
            snapshot = backup.planning
        } catch { context.rollback(); throw error }
    }
}
