import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import NestCore

public struct BankAccount: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let currency: String
    public let balanceCents: Int64
    public init(id: String, name: String, currency: String, balanceCents: Int64) {
        self.id = id; self.name = name; self.currency = currency; self.balanceCents = balanceCents
    }
}
public struct BankEntry: Codable, Identifiable, Sendable {
    /// Canonical provider/account/transaction identifier, stable across pending -> posted.
    public let id: String
    public let merchant: String
    public let cents: Int64
    public let date: Date
    public let kind: EntryKind
    public let pending: Bool
    public let categorySymbol: String
    public let currency: String
    public init(id: String, merchant: String, cents: Int64, date: Date, kind: EntryKind, pending: Bool, categorySymbol: String, currency: String = "AUD") {
        self.id = id; self.merchant = merchant; self.cents = cents; self.date = date; self.kind = kind; self.pending = pending; self.categorySymbol = categorySymbol; self.currency = currency
    }
}
public struct BankSnapshot: Codable, Sendable {
    public let accounts: [BankAccount]
    public let transactions: [BankEntry]
    public let fetchedAt: Date
    public init(accounts: [BankAccount], transactions: [BankEntry], fetchedAt: Date) {
        self.accounts = accounts; self.transactions = transactions; self.fetchedAt = fetchedAt
    }
    public func validate() throws {
        guard accounts.allSatisfy({ $0.currency == "AUD" }),
              transactions.allSatisfy({ $0.currency == "AUD" && $0.cents >= 0 && $0.cents <= 99_999_999_999 && !$0.id.isEmpty && !$0.merchant.isEmpty }),
              Set(transactions.map(\.id)).count == transactions.count else { throw ServiceError.invalidData }
    }
}
public enum ServiceError: Error, LocalizedError {
    case notConfigured, notSignedIn, invalidData, rejected(Int)
    public var errorDescription: String? {
        switch self {
        case .notConfigured: "Live services aren’t configured yet. You can keep exploring the sample workspace."
        case .notSignedIn: "Please sign in again before connecting to live services."
        case .invalidData: "The service returned data Nest couldn’t safely read. Nothing was imported."
        case .rejected(let status): "The service couldn’t complete that request (\(status)). Please try again."
        }
    }
}

public protocol BankProvider: Sendable {
    func snapshot() async throws -> BankSnapshot
    func disconnect() async throws
}

public struct DemoBank: BankProvider {
    public init() {}
    public func snapshot() async throws -> BankSnapshot {
        let calendar = Calendar.current
        var entries: [BankEntry] = []
        for offset in 1...3 {
            let date = calendar.date(byAdding: .month, value: -offset, to: .now)!
            let start = calendar.dateInterval(of: .month, for: date)!.start
            let stamp = "\(calendar.component(.year, from: start))-\(calendar.component(.month, from: start))"
            let rows: [(String, Int64, EntryKind, String)] = [
                ("Sample salary", 320000, .income, "sun.max.fill"),
                ("Sample rent", 120000, .expense, "house.fill"),
                ("Sample groceries", 42000 + Int64(offset * 1300), .expense, "carrot.fill"),
                ("Sample restaurants", 18000 + Int64(offset * 900), .expense, "fork.knife"),
                ("Sample transport", 12000, .expense, "tram.fill"),
                ("Sample books & outings", 12000, .expense, "sparkles")
            ]
            for (index, row) in rows.enumerated() {
                entries.append(BankEntry(id: "nest-demo/\(stamp)/\(index)", merchant: row.0, cents: row.1,
                                         date: calendar.date(byAdding: .day, value: index + 1, to: start)!,
                                         kind: row.2, pending: false, categorySymbol: row.3))
            }
        }
        return BankSnapshot(accounts: [BankAccount(id: "nest-demo", name: "Nest sample everyday", currency: "AUD", balanceCents: 482000)], transactions: entries, fetchedAt: .now)
    }
    public func disconnect() async throws {}
}

/// Backend contract: provider secrets and Yodlee tokens stay on the server.
public struct NestAPI: Sendable {
    public let baseURL: URL
    public let sessionToken: String
    public init(baseURL: URL, sessionToken: String) throws {
        guard baseURL.scheme == "https", baseURL.host != nil, baseURL.user == nil, baseURL.password == nil else { throw ServiceError.notConfigured }
        guard !sessionToken.isEmpty else { throw ServiceError.notSignedIn }
        self.baseURL = baseURL; self.sessionToken = sessionToken
    }
    public func request<Response: Decodable & Sendable>(_ path: String, method: String = "GET", body: Data? = nil, as type: Response.Type) async throws -> Response {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method; request.timeoutInterval = 30
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw ServiceError.invalidData }
        guard (200..<300).contains(response.statusCode) else { throw ServiceError.rejected(response.statusCode) }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
}
public struct LinkSession: Codable, Sendable {
    public let id: String
    public let url: URL
    public let expiresAt: Date
}
public struct Acknowledgement: Codable, Sendable { public let ok: Bool }
public struct LiveBank: BankProvider {
    public let api: NestAPI
    public init(api: NestAPI) { self.api = api }
    public func startLink() async throws -> LinkSession {
        let session = try await api.request("v1/bank/link", method: "POST", as: LinkSession.self)
        guard session.url.scheme == "https", session.url.host == api.baseURL.host, session.expiresAt > .now else { throw ServiceError.invalidData }
        return session
    }
    public func snapshot() async throws -> BankSnapshot {
        let snapshot = try await api.request("v1/bank/snapshot", as: BankSnapshot.self)
        try snapshot.validate(); return snapshot
    }
    public func disconnect() async throws {
        let _: Acknowledgement = try await api.request("v1/bank/connection", method: "DELETE", as: Acknowledgement.self)
    }
}
