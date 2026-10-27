import SwiftUI
import NestCore

struct NestTabs: View {
    @Environment(\.workspaceMode) private var mode
    var body: some View {
        TabView {
            TransactionsView().tabItem { Label("Activity", systemImage: "list.bullet.rectangle") }
            AccountsView().tabItem { Label("Accounts", systemImage: "building.columns") }
            NavigationStack { BudgetsView() }.tabItem { Label("Budgets", systemImage: "chart.pie") }
            ReportsView().tabItem { Label("Reports", systemImage: "chart.bar.fill") }
            NavigationStack {
                List {
                    Section("Plan & explore") {
                        NavigationLink { GoalsView() } label: { Label("Savings goals", systemImage: "flag") }
                        NavigationLink { InsightsView() } label: { Label("Spending insights", systemImage: "chart.xyaxis.line") }
                        NavigationLink { CoachView() } label: { Label("Offline companion", systemImage: "bubble.left.and.bubble.right") }
                    }
                    Section("Your Nest") {
                        NavigationLink { StatementImportView() } label: { Label("Import statement CSV", systemImage: "doc.badge.plus") }
                        NavigationLink { DebtsView() } label: { Label("Debts & loans", systemImage: "arrow.down.right.circle") }
                        NavigationLink { WorkspaceSettingsView() } label: { Label("Workspace & data", systemImage: "externaldrive") }
                        if mode == .demo {
                            NavigationLink { BankingView() } label: { Label("Sample bank", systemImage: "building.columns") }
                        }
                    }
                    Section {
                        Text(mode == .demo
                             ? "You’re exploring fictional data. Switch to your personal workspace to start keeping your own records."
                             : "Your money, on your terms. Records stay on this device; keep a backup in Workspace & data.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }.navigationTitle("Your space").nestPage()
            }.tabItem { Label("More", systemImage: "ellipsis.circle") }
        }.tint(NestTheme.accent).fontDesign(.rounded)
    }
}
