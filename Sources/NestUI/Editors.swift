import SwiftUI
import SwiftData
import NestCore

struct CategoriesView: View {
    @Query(sort: \CategoryRecord.name) private var categories: [CategoryRecord]
    @Environment(\.dismiss) private var dismiss
    @State private var editing: CategoryDraft?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(categories) { category in
                        Button { editing = CategoryDraft(record: category) } label: {
                            HStack {
                                CategoryIcon(symbol: category.symbol, colour: category.colour)
                                Text(category.name).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "pencil").foregroundStyle(.secondary)
                            }
                        }.buttonStyle(.plain)
                    }
                } header: { Text("Make them yours") } footer: {
                    Text("Rename a category whenever you like. Its transactions will stay with it.")
                }
                Button("Create a category", systemImage: "plus.circle") { editing = CategoryDraft() }
            }
            .navigationTitle("Your categories")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $editing) { draft in CategoryEditor(draft: draft) }
        }.fontDesign(.rounded).tint(NestTheme.accent)
            .frame(minWidth: 320, minHeight: 400)
    }
}

private struct CategoryDraft: Identifiable {
    let id = UUID()
    var record: CategoryRecord?
    init(record: CategoryRecord? = nil) { self.record = record }
}

private struct CategoryEditor: View {
    let draft: CategoryDraft
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var categories: [CategoryRecord]
    @State private var name: String
    @State private var colour: String
    @State private var symbol: String
    @State private var error: String?
    private let colours = ["mint", "peach", "lilac", "blue", "pink", "yellow"]
    private let symbols = ["tag.fill", "carrot.fill", "fork.knife", "tram.fill", "house.fill", "sparkles", "sun.max.fill", "heart.fill"]

    init(draft: CategoryDraft) {
        self.draft = draft
        // Intentional editor snapshot: Cancel must not mutate the saved model.
        _name = State(initialValue: draft.record?.name ?? "")
        _colour = State(initialValue: draft.record?.colour ?? "lilac")
        _symbol = State(initialValue: draft.record?.symbol ?? "tag.fill")
    }
    private var valid: Bool {
        Ledger.validCategoryName(name, excluding: draft.record?.id, categories: categories.map(\.value))
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("A name that feels right") {
                    TextField("Category name", text: $name).accessibilityIdentifier("categoryName")
                    Text("Choose a unique name, up to 30 characters.").font(.caption).foregroundStyle(.secondary)
                }
                Section("A splash of colour") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))]) {
                        ForEach(colours, id: \.self) { item in
                            Button { colour = item } label: {
                                VStack {
                                    Circle().fill(NestTheme.colour(item)).frame(width: 36, height: 36)
                                        .overlay { if colour == item { Image(systemName: "checkmark").foregroundStyle(.black) } }
                                    Text(item.capitalized).font(.caption)
                                }.frame(minWidth: 56, minHeight: 64)
                            }.buttonStyle(.plain).accessibilityAddTraits(colour == item ? .isSelected : [])
                        }
                    }
                }
                Section("Choose an icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 52))]) {
                        ForEach(symbols, id: \.self) { item in
                            Button { symbol = item } label: {
                                Image(systemName: item).frame(width: 44, height: 44)
                                    .background(symbol == item ? NestTheme.colour(colour).opacity(0.3) : .clear, in: .rect(cornerRadius: 12))
                            }.buttonStyle(.plain).accessibilityLabel(item.replacingOccurrences(of: ".fill", with: ""))
                                .accessibilityAddTraits(symbol == item ? .isSelected : [])
                        }
                    }
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle(draft.record == nil ? "New category" : "Make it yours")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(!valid) }
            }
        }.fontDesign(.rounded).frame(minWidth: 320, minHeight: 480)
    }
    private func save() {
        guard valid else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let record = draft.record {
            record.name = trimmed; record.colour = colour; record.symbol = symbol
        } else { context.insert(CategoryRecord(NestCore.Category(name: trimmed, symbol: symbol, colour: colour))) }
        do { try context.save(); dismiss() }
        catch { context.rollback(); self.error = "That didn’t save. Please try again." }
    }
}

struct TransactionDetailView: View {
    let record: TransactionRecord
    var body: some View { TransactionEditor(record: record) }
}

struct AddTransactionView: View {
    var body: some View { TransactionEditor(record: nil) }
}

private struct TransactionEditor: View {
    let record: TransactionRecord?
    @Environment(PlanningStore.self) private var plans
    @Query(sort: \CategoryRecord.name) private var categories: [CategoryRecord]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var merchant: String
    @State private var amount: String
    @State private var kind: EntryKind
    @State private var categoryID: UUID?
    @State private var date: Date
    @State private var pending: Bool
    @State private var error: String?
    @State private var confirmDelete = false
    @State private var accountID: UUID
    @State private var transferAccountID: UUID
    private var bankAccounts: [LedgerAccount] {
        ChartOfAccounts.accounts(categories: categories.map(\.value), custom: plans.snapshot.books.accounts).filter(\.isBank)
    }
    private var locked: Bool { record.map { plans.snapshot.books.lockedEntryIDs.contains($0.id) } ?? false }
    private var imported: Bool { record?.providerID?.hasPrefix("nest-demo/") == true }

    init(record: TransactionRecord?) {
        self.record = record
        // Intentional draft: cancelling must leave the persisted record unchanged.
        _merchant = State(initialValue: record?.merchant ?? "")
        _amount = State(initialValue: record.map { editableAmount($0.cents) } ?? "")
        _kind = State(initialValue: record?.value.kind ?? .expense)
        _categoryID = State(initialValue: record?.categoryID)
        _date = State(initialValue: record?.date ?? .now)
        _pending = State(initialValue: record?.pending ?? false)
        _accountID = State(initialValue: record?.accountID ?? ChartOfAccounts.bankID)
        _transferAccountID = State(initialValue: record?.transferAccountID ?? ChartOfAccounts.savingsID)
    }
    private var valid: Bool {
        let trimmed = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 80 && Money.parse(amount) != nil
            && categories.contains { $0.id == categoryID } && (kind != .transfer || accountID != transferAccountID) && !locked
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("The little details") {
                    TextField("Merchant or description", text: $merchant)
                        .accessibilityIdentifier("transactionMerchant").disabled(imported)
                    TextField("Amount in AUD, e.g. 12.50", text: $amount)
                        .accessibilityIdentifier("transactionAmount").disabled(imported)
                    #if os(iOS)
                        .keyboardType(.decimalPad)
                    #endif
                    Picker("Type", selection: $kind) {
                        ForEach(EntryKind.allCases) { item in Text(item.title).tag(item) }
                    }.disabled(imported)
                    DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date).disabled(imported)
                    Picker("Category", selection: $categoryID) {
                        Text("Choose a category").tag(Optional<UUID>.none)
                        ForEach(categories) { category in Text(category.name).tag(Optional(category.id)) }
                    }.accessibilityIdentifier("transactionCategory")
                    Picker(kind == .transfer ? "From account" : "Account", selection: $accountID) {
                        ForEach(bankAccounts) { Text($0.name).tag($0.id) }
                    }.disabled(imported)
                    if kind == .transfer {
                        Picker("To account", selection: $transferAccountID) {
                            ForEach(bankAccounts.filter { $0.id != accountID }) { Text($0.name).tag($0.id) }
                        }
                    }
                    Toggle("Pending", isOn: $pending).disabled(imported)
                }
                .disabled(locked)
                if locked { Text("This entry is reconciled and locked. Remove the relevant reconciliation in Accounts before changing it.").font(.footnote) }
                Section {
                    Text("Use a positive amount with up to two decimal places. Pending transactions and transfers are excluded from income and spending totals.")
                    if imported {
                        Text("This entry came from the sample bank. You can change its category; other details are managed by the sample connection.")
                    } else {
                        Text("Your changes stay on this device. Cancel leaves the saved transaction unchanged.")
                    }
                }.font(.caption).foregroundStyle(.secondary)
                if let error { Text(error).foregroundStyle(.red).accessibilityIdentifier("transactionError") }
                if record != nil, !imported, !locked {
                    Button("Delete transaction", role: .destructive) { confirmDelete = true }
                        .accessibilityIdentifier("deleteTransaction")
                }
            }
            .navigationTitle(record == nil ? "Add a transaction" : "Edit transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(record == nil ? "Add" : "Save", action: save).disabled(!valid)
                        .accessibilityIdentifier("saveTransaction")
                }
            }
            .confirmationDialog("Delete this transaction?", isPresented: $confirmDelete) {
                Button("Delete permanently", role: .destructive) {
                    guard let record else { return }
                    context.delete(record)
                    do { try context.save(); dismiss() }
                    catch { context.rollback(); self.error = "That didn’t save. Please try again." }
                }
            } message: { Text("This removes the entry from your totals. It cannot be undone.") }
        }.fontDesign(.rounded).frame(minWidth: 320, minHeight: 420)
    }
    private func save() {
        guard valid, let cents = Money.parse(amount), let categoryID else { return }
        if let record {
            record.categoryID = categoryID
            if !imported {
                record.merchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
                record.cents = cents; record.kindRaw = kind.rawValue
                record.date = date; record.pending = pending
                record.accountID = accountID; record.transferAccountID = kind == .transfer ? transferAccountID : nil
            }
        } else {
            context.insert(TransactionRecord(Entry(merchant: merchant.trimmingCharacters(in: .whitespacesAndNewlines),
                                                  cents: cents, date: date, kind: kind, categoryID: categoryID, pending: pending, accountID: accountID, transferAccountID: kind == .transfer ? transferAccountID : nil)))
        }
        do {
            let records = try context.fetch(FetchDescriptor<TransactionRecord>())
            let book = try AccountingBook(categories: categories.map(\.value), entries: records.map(\.value), books: plans.snapshot.books)
            try book.validateReconciliations(plans.snapshot.books.reconciliations)
            try context.save(); dismiss()
        } catch { context.rollback(); self.error = "That change could not be saved. If it changes a checked statement, remove the statement check in Accounts first." }
    }
}
