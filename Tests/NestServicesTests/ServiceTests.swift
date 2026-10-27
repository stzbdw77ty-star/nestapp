import Testing
import Foundation
import NestCore
@testable import NestServices

@Test func sampleBankUsesStableIDsAndAUD() async throws {
    let first = try await DemoBank().snapshot()
    let second = try await DemoBank().snapshot()
    try first.validate()
    #expect(first.transactions.count == 18)
    #expect(first.transactions.map(\.id) == second.transactions.map(\.id))
    #expect(first.transactions.allSatisfy { $0.currency == "AUD" })
}
@Test func liveAPIRequiresHTTPSAndASession() {
    #expect(throws: ServiceError.self) { try NestAPI(baseURL: URL(string: "http://example.com")!, sessionToken: "test") }
    #expect(throws: ServiceError.self) { try NestAPI(baseURL: URL(string: "https://example.com")!, sessionToken: "") }
}
@Test func bankSnapshotRejectsDuplicateIDsAndForeignCurrency() async throws {
    let sample = try await DemoBank().snapshot()
    let duplicate = BankSnapshot(accounts: sample.accounts, transactions: sample.transactions + [sample.transactions[0]], fetchedAt: .now)
    #expect(throws: ServiceError.self) { try duplicate.validate() }
    let foreign = BankSnapshot(accounts: [BankAccount(id: "foreign", name: "USD", currency: "USD", balanceCents: 100)], transactions: [], fetchedAt: .now)
    #expect(throws: ServiceError.self) { try foreign.validate() }
}
