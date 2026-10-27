import SwiftUI
import SwiftData
import Charts
import NestCore

struct InsightsView: View {
    @Query private var rows: [TransactionRecord]
    @Query private var categories: [CategoryRecord]
    var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("The bigger picture").font(.largeTitle.bold())
                    Text("Small patterns. A little more perspective.").foregroundStyle(.secondary)
                    TrendCard(entries: rows.map(\.value))
                    VStack(alignment: .leading, spacing: 12) {
                        Label("A gentle check-in", systemImage: "sparkles").font(.headline)
                        Text(Insights.commentary(rows.map(\.value), categories: categories.map(\.value)))
                        Text("Calculated from recorded data, not an AI assessment. Recorded transactions may not represent a whole month.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.nestCard()
                    NavigationLink { LifestyleView(entries: rows.map(\.value), categories: categories.map(\.value)) } label: {
                        Label("Make room for what matters", systemImage: "heart.fill")
                            .font(.headline).frame(maxWidth: .infinity).padding()
                    }.buttonStyle(.borderedProminent)
                }.padding(20).frame(maxWidth: 650).frame(maxWidth: .infinity)
            }.navigationTitle("Insights")
    }
}

struct TrendCard: View {
    let entries: [Entry]
    private var months: [MonthTotal] { Insights.months(entries) }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("In, out & onwards").font(.title2.bold())
            Chart(months) { month in
                BarMark(x: .value("Month", month.month, unit: .month), y: .value("AUD", Double(month.income) / 100))
                    .foregroundStyle(by: .value("Flow", "Income")).position(by: .value("Flow", "Income"))
                BarMark(x: .value("Month", month.month, unit: .month), y: .value("AUD", Double(month.spending) / 100))
                    .foregroundStyle(by: .value("Flow", "Spending")).position(by: .value("Flow", "Spending"))
            }.chartForegroundStyleScale(["Income": NestTheme.colour("mint"), "Spending": NestTheme.colour("peach")])
                .chartXAxis { AxisMarks(values: .stride(by: .month)) { AxisValueLabel(format: .dateTime.month(.abbreviated)) } }
                .frame(height: 220)
            Text("Current month is incomplete. Empty months mean no recorded data, not necessarily no spending. Transfers and pending entries are excluded.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            ForEach(months) { month in
                HStack {
                    Text(month.month.formatted(.dateTime.month(.abbreviated)))
                    Spacer()
                    Text("In \(Money.text(month.income)) · Out \(Money.text(month.spending))")
                }.font(.caption)
            }
        }.nestCard()
    }
}
