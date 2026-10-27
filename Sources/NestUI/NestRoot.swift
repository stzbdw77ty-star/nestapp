import SwiftUI
import SwiftData
import NestCore

private struct WorkspaceModeKey: EnvironmentKey {
    static let defaultValue = WorkspaceMode.personal
}
extension EnvironmentValues {
    var workspaceMode: WorkspaceMode {
        get { self[WorkspaceModeKey.self] }
        set { self[WorkspaceModeKey.self] = newValue }
    }
}

public struct NestRoot: View {
    @AppStorage("nest.workspace") private var selectedWorkspace = ""
    private let inMemory: Bool
    public init(inMemory: Bool = false) { self.inMemory = inMemory }
    public var body: some View {
        Group {
            if inMemory {
                WorkspaceHost(mode: .demo, inMemory: true)
            } else if let mode = WorkspaceMode(rawValue: selectedWorkspace) {
                WorkspaceHost(mode: mode, inMemory: false).id(mode)
            } else {
                WelcomeView { selectedWorkspace = $0.rawValue }
            }
        }.tint(NestTheme.accent).fontDesign(.rounded)
    }
}

private struct WorkspaceHost: View {
    let mode: WorkspaceMode
    let inMemory: Bool
    @State private var container: ModelContainer?
    @State private var plans: PlanningStore?
    @State private var loadFailed = false
    var body: some View {
        Group {
            if let container, let plans {
                NestTabs().modelContainer(container).environment(plans)
                    .environment(\.workspaceMode, mode)
            } else if loadFailed {
                ContentUnavailableView {
                    Label("Let’s try that again", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("We couldn’t open your workspace. Your saved data hasn’t been deleted.")
                } actions: { Button("Try again", action: load) }
            } else { ProgressView("Getting your space ready…") }
        }.task { if container == nil { load() } }
    }
    private func load() {
        do {
            let loadedContainer = try NestPersistence.makeContainer(inMemory: inMemory, mode: mode)
            let loadedPlans = try PlanningStore(context: loadedContainer.mainContext, mode: mode, inMemory: inMemory)
            plans = loadedPlans; container = loadedContainer; loadFailed = false
        } catch { loadFailed = true }
    }
}

private struct WelcomeView: View {
    let choose: (WorkspaceMode) -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "leaf.circle.fill").font(.system(size: 72)).foregroundStyle(NestTheme.accent)
                    .accessibilityHidden(true)
                Text("Make room for\nwhat you love.").font(.largeTitle.bold())
                Text("Welcome to Nest. A little clarity for your spending, a little space for your next chapter.")
                    .font(.title3).foregroundStyle(.secondary)
                Label("Track spending in Australian dollars", systemImage: "list.bullet.rectangle")
                Label("Balance accounts and plan monthly budgets", systemImage: "chart.pie")
                Label("Keep your records on this device", systemImage: "lock.shield")
                Button { choose(.personal) } label: {
                    Text("Start my Nest").frame(maxWidth: .infinity).padding(.vertical, 8)
                }.buttonStyle(.borderedProminent).accessibilityIdentifier("startPersonalWorkspace")
                Button { choose(.demo) } label: {
                    Text("Explore with sample data").frame(maxWidth: .infinity).padding(.vertical, 8)
                }.buttonStyle(.bordered).accessibilityIdentifier("startDemoWorkspace")
                Text("No account or bank connection needed. The sample workspace is separate from your personal records. You can switch anytime in More.")
                    .font(.footnote).foregroundStyle(.secondary)
            }.padding(28).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }.background(NestTheme.colour("peach").opacity(0.12))
    }
}

#Preview { NestRoot(inMemory: true) }
