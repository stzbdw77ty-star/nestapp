import SwiftUI
import SwiftData

public struct TransactionsView: View {
    @Query(sort: \CategoryRecord.name) private var categories: [CategoryRecord]
    @Query(sort: \TransactionRecord.date, order: .reverse) private var records: [TransactionRecord]
    @State private var sheet: Sheet?
    public init() {}

    private enum Sheet: Identifiable {
        case categories, add, transaction(TransactionRecord)
        var id: String {
            switch self {
            case .categories: "categories"
            case .add: "add"
            case .transaction(let record): record.id.uuidString
            }
        }
    }

    public var body: some View {
        TransactionScreen(categories: categories.map(\.value), entries: records.map(\.value),
                          onAdd: { sheet = .add }, onCategories: { sheet = .categories },
                          onOpen: { id in
                              if let record = records.first(where: { $0.id == id }) { sheet = .transaction(record) }
                          })
            .sheet(item: $sheet) { destination in
                switch destination {
                case .categories: CategoriesView()
                case .add: AddTransactionView()
                case .transaction(let record): TransactionDetailView(record: record)
                }
            }
    }
}
