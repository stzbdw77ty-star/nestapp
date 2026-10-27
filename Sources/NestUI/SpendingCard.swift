import SwiftUI
import Charts
import NestCore

struct SpendingCard: View {
    let totals: [CategoryTotal]
    @Binding var selectedID: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedAngle: Double?
    private var selected: NestCore.CategoryTotal? { totals.first { $0.id == selectedID } }
    private var sum: Int64 { totals.reduce(0) { $0 + $1.cents } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("A colourful little breakdown").font(.title2.bold())
            Text("Tap a slice or category to explore your spending.")
                .font(.subheadline).foregroundStyle(.secondary)
            if totals.isEmpty {
                ContentUnavailableView("Nothing spent here yet", systemImage: "sun.max",
                                       description: Text("Your chart will grow as you add expenses."))
            } else {
                Chart(totals) { total in
                    SectorMark(angle: .value("Spending in AUD", Double(total.cents) / 100),
                               innerRadius: .ratio(0.74),
                               outerRadius: .ratio(selectedID == total.id ? 1 : 0.94), angularInset: 3)
                    .cornerRadius(5)
                    .foregroundStyle(by: .value("Category", total.category.name))
                    .opacity(selectedID == nil || selectedID == total.id ? 1 : 0.4)
                    .accessibilityLabel(total.category.name)
                    .accessibilityValue(Money.text(total.cents))
                }
                .chartForegroundStyleScale(domain: totals.map(\.category.name), range: totals.map { NestTheme.colour($0.category.colour) })
                .chartLegend(.hidden)
                .chartAngleSelection(value: $selectedAngle)
                .frame(height: 230)
                .overlay {
                    VStack(spacing: 4) {
                        Text(selected?.category.name ?? "Spent this month").font(.caption).foregroundStyle(.secondary)
                        Text(Money.text(selected?.cents ?? sum)).font(.title2.bold()).monospacedDigit()
                    }.frame(maxWidth: 155).allowsHitTesting(false).accessibilityHidden(true)
                }
                .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: selectedID)
                .onChange(of: selectedAngle) {
                    guard let selectedAngle else { return }
                    var cumulative = 0.0
                    for item in totals {
                        cumulative += Double(item.cents) / 100
                        if selectedAngle < cumulative { selectedID = item.id; break }
                    }
                }
                ForEach(totals) { total in
                    Button {
                        selectedID = selectedID == total.id ? nil : total.id
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: total.category.symbol).frame(width: 22)
                                .padding(6).background(NestTheme.colour(total.category.colour).opacity(0.24), in: .circle)
                            Text(total.category.name).font(.subheadline.weight(.medium))
                            Spacer()
                            Text(Money.text(total.cents)).font(.subheadline).monospacedDigit()
                            Image(systemName: selectedID == total.id ? "checkmark.circle.fill" : "chevron.right")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 3).frame(minHeight: 44).contentShape(.rect)
                    }.buttonStyle(.plain)
                        .accessibilityAddTraits(selectedID == total.id ? .isSelected : [])
                        .accessibilityHint("Filter transactions by this category")
                }
                Text("Posted expenses only · All categories · AUD")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.nestCard()
    }
}
