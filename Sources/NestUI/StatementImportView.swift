import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import NestCore

struct StatementImportView: View {
    @Environment(PlanningStore.self) private var plans
    @Environment(\.modelContext) private var context
    @Query private var categories: [CategoryRecord]
    @Query private var records: [TransactionRecord]
    @State private var importing = false
    @State private var preview: [StatementRow] = []
    @State private var message: String?
    private var existingIDs: Set<String> { Set(records.compactMap(\.providerID)) }
    private var fresh: [StatementRow] { preview.filter { !existingIDs.contains($0.sourceID) } }
    var body: some View {
        List {
            Section {
                Text("Bring your statement into Nest.").font(.title2.bold())
                Text("Import a prepared UTF-8 CSV. Check its columns before choosing a file; bank export formats vary. A preview appears before anything is saved.").font(.footnote)
                Text(StatementCSV.header.joined(separator: ",")).font(.caption.monospaced()).textSelection(.enabled)
                Text("Dates: YYYY-MM-DD. Amounts: positive AUD, up to two decimals. Type: expense, income or transfer. Category and account names must already exist in Nest. to_account is required only for transfers.").font(.caption)
                Text("Use the bank’s stable transaction ID for id. IDs are checked per account, so importing the same statement again skips existing entries and preserves your category choices.").font(.caption)
                Button("Choose CSV", systemImage: "doc.badge.plus") { importing = true }
            }
            if !preview.isEmpty {
                Section("Review before importing") {
                    LabeledContent("Ready to add", value: "\(fresh.count)")
                    LabeledContent("Already imported · skipped", value: "\(preview.count - fresh.count)")
                    ForEach(Array(fresh.prefix(20)), id: \.sourceID) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack { Text(row.entry.merchant); Spacer(); Text(Money.text(row.entry.cents)).monospacedDigit() }
                            Text("\(row.entry.date.formatted(date: .abbreviated, time: .omitted)) · \(row.entry.kind.title)").font(.caption)
                        }
                    }
                    if fresh.count > 20 { Text("Showing the first 20 of \(fresh.count) new entries.").font(.caption) }
                    Button("Import \(fresh.count) entries", action: save).disabled(fresh.isEmpty)
                    Button("Cancel preview", role: .cancel) { preview = [] }
                }
            }
            if let message { Section { Text(message).font(.footnote) } }
        }.navigationTitle("Import statement").nestPage()
            .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size <= 10_000_000 else { throw StatementCSVError.invalid("Choose a CSV smaller than 10 MB.") }
                    preview = try StatementCSV.parse(Data(contentsOf: url), categories: categories.map(\.value), accounts: ChartOfAccounts.accounts(categories: categories.map(\.value), custom: plans.snapshot.books.accounts))
                    message = nil
                } catch { preview = []; message = error.localizedDescription }
            }
    }
    private func save() {
        do {
            let rows = fresh
            for row in rows {
                let record = TransactionRecord(row.entry); record.providerID = row.sourceID; context.insert(record)
            }
            let all = try context.fetch(FetchDescriptor<TransactionRecord>())
            let book = try AccountingBook(categories: categories.map(\.value), entries: all.map(\.value), books: plans.snapshot.books)
            try book.validateReconciliations(plans.snapshot.books.reconciliations)
            try context.save()
            message = "Imported \(rows.count) entries. Existing imported records were left unchanged."; preview = []
        } catch {
            context.rollback()
            message = "Nothing was imported. Check your data and remove statement checks in Accounts if these entries change an already checked period."
        }
    }
}
