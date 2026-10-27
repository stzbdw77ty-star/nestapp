import SwiftUI
import SwiftData
import NestCore
import NestServices

private struct ChatMessage: Identifiable { let id = UUID(); let fromUser: Bool; let text: String }
struct CoachView: View {
    @Environment(\.workspaceMode) private var mode
    @Query private var records: [TransactionRecord]
    @Environment(PlanningStore.self) private var plans
    @State private var messages: [ChatMessage] = []
    @State private var question = ""
    @State private var busy = false
    @State private var useAI = false
    @State private var shareSummary = false
    @State private var error: String?
    private var liveAPI: NestAPI? { nil } // Live integrations are outside the offline MVP.
    var body: some View {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Let’s talk money.").font(.largeTitle.bold())
                            Text(useAI ? "Connected AI · Educational support" : "Offline guide · Prepared explanations, not live AI")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("A friendly space for questions about spending, goals and the basics.")
                            if liveAPI != nil {
                                Toggle("Use connected AI", isOn: $useAI)
                                if useAI {
                                    Toggle("Share my financial summary with the AI service", isOn: $shareSummary)
                                    Text("Sends your question, monthly totals and saved budget scenario. Merchant details and account numbers are excluded. Avoid personal details in questions.").font(.caption)
                                }
                            }
                            ForEach(["How is my spending going?", "How could I save more?", "How does loan interest work?"], id: \.self) { prompt in
                                Button(prompt) { question = prompt }.buttonStyle(.bordered)
                            }
                            ForEach(messages) { message in
                                Text(message.text).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(message.fromUser ? NestTheme.colour("lilac").opacity(0.2) : NestTheme.colour("mint").opacity(0.16), in: .rect(cornerRadius: 20))
                                    .textSelection(.enabled).id(message.id)
                                    .accessibilityLabel("\(message.fromUser ? "You" : "Nest"): \(message.text)")
                            }
                            if busy { ProgressView("Thinking it through…") }
                            if let error { Text(error).foregroundStyle(.red).font(.footnote) }
                        }.padding(20).frame(maxWidth: 650).frame(maxWidth: .infinity)
                    }.onChange(of: messages.count) {
                        if let id = messages.last?.id { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }
                HStack {
                    TextField("What’s on your mind?", text: $question, axis: .vertical).lineLimit(1...4)
                        .textFieldStyle(.plain).onSubmit { Task { await send() } }
                    Button { Task { await send() } } label: { Image(systemName: "arrow.up.circle.fill").font(.title) }
                        .accessibilityLabel("Send question").disabled(busy || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || question.count > 2000 || (useAI && !shareSummary))
                }.padding(16)
            }.navigationTitle("Nest companion")
                .toolbar { Button("Clear chat") { messages = []; error = nil }.disabled(busy) }
    }
    private func send() async {
        let prompt = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !busy, !prompt.isEmpty, prompt.count <= 2000, !useAI || shareSummary else { return }
        busy = true; error = nil; defer { busy = false }
        messages.append(ChatMessage(fromUser: true, text: prompt)); question = ""
        let rows = Ledger.entries(records.map(\.value), month: .now)
        let summary = CoachContext(incomeCents: Ledger.total(rows, kind: .income), spendingCents: Ledger.total(rows, kind: .expense), plan: plans.snapshot.lifestyle, sampleData: mode == .demo)
        do {
            let coach: any FinanceCoach
            if useAI {
                guard let api = liveAPI else { throw ServiceError.notConfigured }
                coach = LiveCoach(api: api)
            } else { coach = LocalCoach() }
            let answer = try await coach.reply(to: prompt, context: summary)
            messages.append(ChatMessage(fromUser: false, text: answer))
        } catch { self.error = "We couldn’t get a reply. \(error.localizedDescription)"; question = prompt }
    }
}
