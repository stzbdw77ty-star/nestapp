import SwiftUI
import NestCore

func amountOrZero(_ text: String) -> Int64? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return ["0", "0.0", "0.00"].contains(trimmed) ? 0 : Money.parse(trimmed)
}
func editableAmount(_ cents: Int64) -> String { String(format: "%.2f", Double(cents) / 100) }

struct GoalsView: View {
    @Environment(PlanningStore.self) private var plans
    @State private var draft: GoalDraft?
    @State private var showFI = false
    var body: some View {
            List {
                Section {
                    Text("Something lovely to work towards.").font(.title2.bold())
                    Text("Give your next chapter a name. Track money you’ve actually set aside, then explore the pace to reach it.")
                        .foregroundStyle(.secondary)
                }
                ForEach(plans.snapshot.goals) { goal in
                    Button { draft = GoalDraft(goal: goal) } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack { Label(goal.name, systemImage: goal.kind == .holiday ? "sun.max.fill" : "flag.fill"); Spacer(); Text("\(Int(goal.progress * 100))%") }
                                .font(.headline)
                            ProgressView(value: goal.progress).tint(NestTheme.colour("mint"))
                            Text("\(Money.text(goal.saved)) of \(Money.text(goal.target))").font(.subheadline)
                            if let pace = goal.monthlyPace() {
                                Text(pace == 0 ? "You’ve reached this goal. Lovely work!" : "About \(Money.text(pace))/month to \(goal.deadline.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption).foregroundStyle(.secondary)
                            } else { Text("Your date has arrived. Update the goal when you’re ready.").font(.caption) }
                        }.padding(16).foregroundStyle(.primary)
                            .background(NestTheme.colour(goal.kind == .holiday ? "peach" : "mint").opacity(0.18), in: .rect(cornerRadius: 22))
                    }.buttonStyle(.plain).listRowSeparator(.hidden)
                }
                if plans.snapshot.goals.isEmpty {
                    ContentUnavailableView("Your next chapter starts here", systemImage: "flag", description: Text("Tap + to add a holiday, purchase or independence goal."))
                }
                Section {
                    Button("Explore financial independence", systemImage: "leaf") { showFI = true }
                    Text("Goal balances are manual records, not bank balances. Allocate each dollar to one goal to avoid counting it twice.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.navigationTitle("Your goals")
                .toolbar { Button { draft = GoalDraft() } label: { Label("New goal", systemImage: "plus") } }
                .sheet(item: $draft) { GoalEditor(draft: $0) }
                .sheet(isPresented: $showFI) { IndependenceView() }
    }
}

private struct GoalDraft: Identifiable { let id = UUID(); var goal: SavingsGoal? }
private struct GoalEditor: View {
    let draft: GoalDraft
    @Environment(PlanningStore.self) private var plans
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var kind: GoalKind
    @State private var target: String
    @State private var saved: String
    @State private var date: Date
    @State private var error: String?
    @State private var confirmDelete = false
    init(draft: GoalDraft) {
        self.draft = draft
        _name = State(initialValue: draft.goal?.name ?? "")
        _kind = State(initialValue: draft.goal?.kind ?? .holiday)
        _target = State(initialValue: draft.goal.map { editableAmount($0.target) } ?? "")
        _saved = State(initialValue: draft.goal.map { editableAmount($0.saved) } ?? "0")
        _date = State(initialValue: draft.goal?.deadline ?? Calendar.current.date(byAdding: .year, value: 1, to: .now)!)
    }
    var body: some View {
        NavigationStack {
            Form {
                TextField("Give it a name", text: $name)
                Picker("Kind", selection: $kind) { ForEach(GoalKind.allCases) { Text($0.rawValue).tag($0) } }
                TextField("Target (AUD)", text: $target)
                TextField("Already saved (AUD)", text: $saved)
                DatePicker("Target date", selection: $date, displayedComponents: .date)
                Text("The monthly pace assumes regular saving and no investment return. It is an estimate, not a scheduled transfer.").font(.caption)
                if let error { Text(error).foregroundStyle(.red) }
                if draft.goal != nil { Button("Delete goal", role: .destructive) { confirmDelete = true } }
            }.navigationTitle(draft.goal == nil ? "A new possibility" : "Your next chapter")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
                }
                .confirmationDialog("Delete this goal?", isPresented: $confirmDelete) {
                    Button("Delete goal", role: .destructive) {
                        do { try plans.update { $0.goals.removeAll { $0.id == draft.goal?.id } }; dismiss() }
                        catch { self.error = "Couldn’t save that change. Please try again." }
                    }
                }
        }.frame(minWidth: 320, minHeight: 420)
    }
    private func save() {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 60, let target = Money.parse(target), let saved = amountOrZero(saved) else {
            error = "Add a name and valid amounts, with a target above zero."; return
        }
        let goal = SavingsGoal(id: draft.goal?.id ?? UUID(), name: title, kind: kind, target: target, saved: saved, deadline: date)
        do {
            try plans.update { snapshot in
                if let index = snapshot.goals.firstIndex(where: { $0.id == goal.id }) { snapshot.goals[index] = goal }
                else { snapshot.goals.append(goal) }
            }; dismiss()
        } catch { self.error = "That didn’t save. Please try again." }
    }
}

private struct IndependenceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var spending = "48000"
    @State private var rate = 4.0
    var body: some View {
        NavigationStack {
            Form {
                Section("Explore a target") {
                    TextField("Annual spending (AUD)", text: $spending)
                    Text("Assumed annual withdrawal: \(rate, specifier: "%.1f")%")
                    Slider(value: $rate, in: 2...6, step: 0.1)
                    if let annual = Money.parse(spending), let target = Planning.independenceTarget(annualSpending: annual, withdrawalPercent: rate) {
                        Text(Money.text(target)).font(.largeTitle.bold())
                        Text("Illustrative portfolio target").foregroundStyle(.secondary)
                    }
                }
                Text("Annual spending divided by the withdrawal rate. This is a scenario, not a safe withdrawal recommendation. Taxes, fees, inflation, investment losses and retirement length can change what you need. You can use a chosen target when creating a financial independence goal.")
                    .font(.footnote)
            }.navigationTitle("Room to dream")
                .toolbar { Button("Done") { dismiss() } }
        }.frame(minWidth: 320, minHeight: 440)
    }
}
