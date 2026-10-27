import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import NestCore

private struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw BackupError.invalid }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct WorkspaceSettingsView: View {
    @Environment(\.workspaceMode) private var mode
    @Environment(PlanningStore.self) private var plans
    @Query private var categories: [CategoryRecord]
    @Query private var entries: [TransactionRecord]
    @AppStorage("nest.workspace") private var selectedWorkspace = ""
    @AppStorage("nest.appearance") private var appearance = "system"
    @State private var document = BackupDocument()
    @State private var exporting = false
    @State private var importing = false
    @State private var pendingBackup: WorkspaceBackup?
    @State private var confirmRestore = false
    @State private var message: String?
    var body: some View {
        List {
            Section("Your workspace") {
                Label(mode.title, systemImage: mode == .demo ? "leaf" : "person.crop.circle")
                Text(mode == .demo
                     ? "Fictional transactions for exploring Nest. Your personal records are kept in a separate workspace."
                     : "Your manual records stay in this device’s local storage. No bank accounts are connected.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button(mode == .demo ? "Open my personal workspace" : "Explore sample workspace") {
                    selectedWorkspace = (mode == .demo ? WorkspaceMode.personal : .demo).rawValue
                }.accessibilityIdentifier("switchWorkspace")
            }
            if mode == .personal {
                Section("Keep a copy") {
                    Button("Export a backup", systemImage: "square.and.arrow.up") { export() }
                        .accessibilityIdentifier("exportBackup")
                    Button("Restore from a backup", systemImage: "square.and.arrow.down") { importing = true }
                    Text("A JSON backup includes transactions, categories, accounts, budgets, statement checks, goals, debts and your lifestyle plan. It contains personal financial information. Choose a private storage location. Nest does not upload it or sync it between devices.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("Make it yours") {
                Picker("Appearance", selection: $appearance) {
                    Text("Use device setting").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
            }
            Section("About Nest") {
                Text("Nest · Household accounts · 0.2.0").font(.headline)
                Text("A personal finance tracker in AUD. Plans are illustrations, not financial advice. Nest does not move money, connect to real banks, or sell subscriptions in this version.")
                Text("The companion is an offline guide with prepared explanations. It is not live AI. Chat clears when you close the app.")
                Text("Deleting the app can delete its records. Export a backup before changing devices.")
            }.font(.footnote)
            if let message { Section { Text(message).accessibilityIdentifier("backupMessage") } }
        }.navigationTitle("Workspace & data").nestPage()
            .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "Nest-backup") { result in
                switch result {
                case .success: message = "Your backup has been exported. Keep it somewhere private."
                case .failure: message = "The backup wasn’t exported. Please try again."
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size <= 25_000_000 else { throw BackupError.invalid }
                    pendingBackup = try WorkspaceBackup.decode(Data(contentsOf: url))
                    confirmRestore = true
                } catch { message = "That backup couldn’t be opened. Your records haven’t changed." }
            }
            .confirmationDialog("Replace this workspace with the backup?", isPresented: $confirmRestore) {
                Button("Replace personal records", role: .destructive) { restore() }
                Button("Cancel", role: .cancel) { pendingBackup = nil }
            } message: {
                Text("This replaces all personal transactions, categories and plans. Export your current records first if you want to keep them. Sample data is unaffected.")
            }
    }
    private func export() {
        do {
            document = BackupDocument(data: try WorkspaceBackup(categories: categories.map(\.value), entries: entries.map(\.value), planning: plans.snapshot, sourceIDs: Dictionary(uniqueKeysWithValues: entries.compactMap { entry in entry.providerID.map { (entry.id.uuidString, $0) } })).encoded())
            exporting = true
        } catch { message = "Your backup couldn’t be created. Your saved records haven’t changed." }
    }
    private func restore() {
        guard let backup = pendingBackup else { return }
        defer { pendingBackup = nil }
        do { try plans.restore(backup); message = "Your personal workspace has been restored." }
        catch { message = "Restore failed. Your records haven’t changed. Please try again." }
    }
}
