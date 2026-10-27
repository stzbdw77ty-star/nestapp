import Testing
import Foundation
import SwiftData
import NestCore
@testable import NestUI

@MainActor @Test func personalWorkspaceStartsWithoutFictionalTransactions() throws {
    let container = try NestPersistence.makeContainer(inMemory: true, mode: .personal)
    let context = container.mainContext
    #expect(try context.fetchCount(FetchDescriptor<CategoryRecord>()) == 7)
    #expect(try context.fetchCount(FetchDescriptor<TransactionRecord>()) == 0)
}

@MainActor @Test func demoAndPersonalContainersDoNotShareRecords() throws {
    let demo = try NestPersistence.makeContainer(inMemory: true, mode: .demo)
    let personal = try NestPersistence.makeContainer(inMemory: true, mode: .personal)
    #expect(try demo.mainContext.fetchCount(FetchDescriptor<TransactionRecord>()) == 11)
    #expect(try personal.mainContext.fetchCount(FetchDescriptor<TransactionRecord>()) == 0)
}

@MainActor @Test func restoreReplacesLedgerAndPlansTogetherAndIsRepeatable() throws {
    let container = try NestPersistence.makeContainer(inMemory: true, mode: .personal)
    let context = container.mainContext
    let plans = try PlanningStore(context: context, mode: .personal, inMemory: true)
    let sample = SampleData.make()
    var snapshot = PlanningSnapshot()
    snapshot.goals = [SavingsGoal(name: "Trip", kind: .holiday, target: 100000, saved: 20000, deadline: .now)]
    let backup = WorkspaceBackup(categories: sample.categories, entries: sample.entries, planning: snapshot)
    try plans.restore(backup)
    try plans.restore(backup)
    #expect(try context.fetchCount(FetchDescriptor<TransactionRecord>()) == 11)
    #expect(try context.fetchCount(FetchDescriptor<CategoryRecord>()) == 7)
    #expect(plans.snapshot == snapshot)
    let reopened = try PlanningStore(context: context, mode: .personal, inMemory: true)
    #expect(reopened.snapshot == snapshot)
    var invalid = backup
    invalid.entries[0].cents = -1
    #expect(throws: BackupError.self) { try plans.restore(invalid) }
    #expect(try context.fetchCount(FetchDescriptor<TransactionRecord>()) == 11)
    #expect(plans.snapshot == snapshot)
}

@MainActor @Test func personalRecordsSurviveStoreReopen() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("NestTest.store")
    func write() throws {
        let container = try NestPersistence.makeContainer(mode: .personal, storeURL: url)
        let context = container.mainContext
        let categories = try context.fetch(FetchDescriptor<CategoryRecord>())
        context.insert(TransactionRecord(Entry(merchant: "My groceries", cents: 12345, date: .now, kind: .expense, categoryID: categories[0].id)))
        let plans = try PlanningStore(context: context, mode: .personal, inMemory: true)
        try plans.update { $0.goals = [SavingsGoal(name: "Trip", kind: .holiday, target: 100000, saved: 100, deadline: .now)] }
    }
    try write()
    let reopened = try NestPersistence.makeContainer(mode: .personal, storeURL: url)
    let entries = try reopened.mainContext.fetch(FetchDescriptor<TransactionRecord>())
    #expect(entries.count == 1)
    #expect(entries.first?.merchant == "My groceries")
    #expect(entries.first?.cents == 12345)
    let plans = try PlanningStore(context: reopened.mainContext, mode: .personal, inMemory: true)
    #expect(plans.snapshot.goals.first?.name == "Trip")
}
