import SwiftUI
import SwiftData
import NestCore
import NestServices

struct BankingView: View {
    @Environment(PlanningStore.self) private var plans
    @Environment(\.modelContext) private var context
    @Query private var records: [TransactionRecord]
    @Query private var categories: [CategoryRecord]
    @AppStorage("nest.demoBankConnected") private var connected = false
    @AppStorage("nest.demoBankSync") private var lastSync = 0.0
    @State private var busy = false
    @State private var message: String?
    @State private var removeData = false
    @State private var showLiveSetup = false

    var body: some View {
        List {
            Section {
                Label("Your connected accounts", systemImage: "building.columns.fill").font(.title2.bold())
                Text("Try the full sample connection flow before linking a real account.").foregroundStyle(.secondary)
            }
            Section("Sample workspace") {
                if connected {
                    Label("Nest sample everyday", systemImage: "checkmark.seal.fill")
                    Text("Fictional balance: A$4,820.00").font(.headline)
                    Text("AUD · Sample provider · No real bank access").font(.caption)
                    if lastSync > 0 { Text("Refreshed \(Date(timeIntervalSince1970: lastSync).formatted(date: .abbreviated, time: .shortened))").font(.caption) }
                    Button("Refresh sample transactions") { Task { await sync() } }.disabled(busy)
                    Button("Disconnect sample bank", role: .destructive) { connected = false; message = "Disconnected. Imported sample history stays until you remove it." }
                } else {
                    Button("Connect sample bank") { Task { await sync() } }.disabled(busy)
                }
                Text("Adds three months of fictional history. Refreshing updates existing imported entries without duplicating them or undoing your category choices.")
                    .font(.caption)
                if records.contains(where: { $0.providerID?.hasPrefix("nest-demo/") == true }) {
                    Button("Remove imported sample history", role: .destructive) { removeData = true }
                }
                if busy { ProgressView("Bringing your sample history together…") }
                if let message { Text(message).font(.footnote) }
            }
            Section {
                Button("About real bank connections") { showLiveSetup = true }
            }
        }.navigationTitle("Bank accounts")
            .confirmationDialog("Remove the imported sample history?", isPresented: $removeData) {
                Button("Remove sample history", role: .destructive) {
                    do {
                        records.filter { $0.providerID?.hasPrefix("nest-demo/") == true }.forEach { context.delete($0) }
                        try validateBooks(); try context.save(); connected = false; lastSync = 0
                    } catch { context.rollback(); message = "That didn’t save. Remove affected statement checks in Accounts first." }
                }
            }
            .alert("Live banking is the next connection step", isPresented: $showLiveSetup) {
                Button("Got it", role: .cancel) {}
            } message: {
                Text("This build uses a sample workspace. Real banking needs an approved provider connection and secure sign-in. Nest’s live service adapter is included, but it isn’t connected to a bank yet.")
            }
    }
    private func validateBooks() throws {
        let all = try context.fetch(FetchDescriptor<TransactionRecord>())
        let book = try AccountingBook(categories: categories.map(\.value), entries: all.map(\.value), books: plans.snapshot.books)
        try book.validateReconciliations(plans.snapshot.books.reconciliations)
    }
    private func sync() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do {
            let snapshot = try await DemoBank().snapshot()
            try snapshot.validate()
            var lookup = Dictionary(uniqueKeysWithValues: records.compactMap { record in record.providerID.map { ($0, record) } })
            for entry in snapshot.transactions {
                if let record = lookup[entry.id] {
                    record.merchant = entry.merchant; record.cents = entry.cents; record.date = entry.date
                    record.kindRaw = entry.kind.rawValue; record.pending = entry.pending
                    // Preserve the user's category, including across pending -> posted updates.
                } else {
                    guard let category = categories.first(where: { $0.symbol == entry.categorySymbol }) ?? categories.first else { throw ServiceError.invalidData }
                    let record = TransactionRecord(Entry(merchant: entry.merchant, cents: entry.cents, date: entry.date,
                                                        kind: entry.kind, categoryID: category.id, pending: entry.pending))
                    record.providerID = entry.id; context.insert(record); lookup[entry.id] = record
                }
            }
            try validateBooks(); try context.save(); connected = true; lastSync = snapshot.fetchedAt.timeIntervalSince1970
            message = "Your sample history is ready. Head to Insights to explore the last few months."
        } catch { context.rollback(); message = error.localizedDescription }
    }
}
