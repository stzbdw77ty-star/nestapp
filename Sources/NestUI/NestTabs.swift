import SwiftUI
import NestCore

struct NestTabs: View {
    @Environment(\.workspaceMode) private var mode
    var body: some View {
        TabView {
            OverviewView().tabItem { Label("Home", systemImage: "square.grid.2x2.fill") }
            TransactionsView().tabItem { Label("Activity", systemImage: "list.bullet.rectangle") }
            NavigationStack { AccountsView() }.tabItem { Label("Accounts", systemImage: "building.columns") }
            NavigationStack { BudgetsView() }.tabItem { Label("Budgets", systemImage: "chart.pie") }
            NavigationStack {
                List {
                    Section("Plan & explore") {
                        NavigationLink { ReportsView() } label: { Label("Reports & exports", systemImage: "chart.bar.fill") }
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
