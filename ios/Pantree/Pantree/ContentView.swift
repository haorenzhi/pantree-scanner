import Charts
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
            InventoryView()
                .tabItem { Label("Inventory", systemImage: "refrigerator.fill") }
            ReceiptScannerView()
                .tabItem { Label("Receipt", systemImage: "doc.text.viewfinder") }
            FoodPhotoPredictionView()
                .tabItem { Label("Diet", systemImage: "fork.knife.circle.fill") }
        }
        .accessibilityIdentifier("PantreeRoot")
    }
}

struct DashboardView: View {
    @EnvironmentObject private var store: LocalFoodStore

    var summary: PantrySummary { store.summary() }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    PrivacyBanner()
                }
                .listRowBackground(Color.clear)

                Section {
                    MetricGrid(summary: summary)
                }
                .listRowBackground(Color.clear)

                Section {
                    HealthPanel(summary: summary)
                }
                .listRowBackground(Color.clear)

                Section("Eat first") {
                    if summary.expiryRisks.isEmpty {
                        Text("No urgent expiration risk right now.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(summary.expiryRisks.prefix(5)) { risk in
                            RiskRow(risk: risk)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button {
                                        _ = try? store.consume(itemId: risk.item.id)
                                    } label: {
                                        Label("Ate", systemImage: "fork.knife")
                                    }
                                    .tint(.green)
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        _ = try? store.discard(itemId: risk.item.id)
                                    } label: {
                                        Label("Discard", systemImage: "trash")
                                    }
                                    .tint(.red)
                                }
                                .listRowBackground(FoodExpirationStyle.rowBackground(for: risk.item))
                        }
                    }
                }

                Section {
                    ShoppingPanel(suggestions: summary.shoppingSuggestions)
                }
                .listRowBackground(Color.clear)

                Section {
                    MealPanel(meals: summary.mealIdeas)
                }
                .listRowBackground(Color.clear)

                Section {
                    MLReadinessPanel(notes: summary.mlReadiness)
                }
                .listRowBackground(Color.clear)
            }
            .listStyle(.insetGrouped)
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .navigationTitle("Pantree")
        }
    }
}

struct PrivacyBanner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Local-only food intelligence", systemImage: "lock.shield.fill")
                .font(.headline)
            Text("Receipt text, inventory events, and food photo predictions stay on this iPhone. No external APIs are used in this POC.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.green.opacity(0.13), in: RoundedRectangle(cornerRadius: 18))
        .accessibilityIdentifier("PrivacyBanner")
    }
}

struct MetricGrid: View {
    var summary: PantrySummary

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricCard(title: "Expiring soon", value: "\(summary.expiryRisks.count)/\(summary.activeCount)", detail: "foods over active")
            MetricCard(title: "Health score", value: "\(summary.healthBalance.score)/100", detail: "local heuristic")
            MetricCard(title: "Value at risk", value: summary.valueAtRisk.currencyText, detail: "expiring soon")
            MetricCard(title: "Inventory value", value: summary.totalEstimatedValue.currencyText, detail: "remaining estimate")
        }
    }
}

struct MetricCard: View {
    var title: String
    var value: String
    var detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.bold())
            Text(detail).font(.caption2).foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct HealthPanel: View {
    var summary: PantrySummary

    var balance: HealthBalance { summary.healthBalance }

    var slices: [CategorySlice] {
        FoodCategory.allCases.compactMap { category in
            let count = summary.categoryCounts[category, default: 0]
            guard count > 0 else { return nil }
            return CategorySlice(category: category, count: count)
        }
    }

    var body: some View {
        Panel(title: "Diet balance") {
            VStack(alignment: .leading, spacing: 8) {
                if slices.isEmpty {
                    Text("Add food to see an inventory category chart.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    CategoryPieChart(slices: slices)
                        .frame(height: 190)
                        .accessibilityIdentifier("DietBalancePieChart")

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 6) {
                        ForEach(slices) { slice in
                            Label("\(slice.category.title): \(slice.count)", systemImage: "circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                ForEach(balance.insights, id: \.self) { insight in
                    Label(insight, systemImage: "leaf.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct CategorySlice: Identifiable {
    var category: FoodCategory
    var count: Int

    var id: FoodCategory { category }
}

struct CategoryPieChart: View {
    var slices: [CategorySlice]

    var body: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("Foods", slice.count),
                innerRadius: .ratio(0.58),
                angularInset: 1.5
            )
            .foregroundStyle(by: .value("Category", slice.category.title))
        }
        .chartLegend(position: .bottom, alignment: .center)
    }
}

struct RiskRow: View {
    var risk: ExpiryRisk

    private var expirationText: String {
        if risk.daysLeft < 0 {
            let days = abs(risk.daysLeft)
            return "Expired \(days) day\(days == 1 ? "" : "s") ago"
        }
        if risk.daysLeft == 0 {
            return "Expires today"
        }
        return "Expiring in \(risk.daysLeft) day\(risk.daysLeft == 1 ? "" : "s")"
    }

    var body: some View {
        HStack(spacing: 10) {
            FoodIconBadge(item: risk.item)
            VStack(alignment: .leading, spacing: 4) {
                Text(risk.item.name).font(.headline)
                Text(risk.reason).font(.caption).foregroundStyle(.secondary)
                if let value = risk.valueAtRisk {
                    Text("Value at risk: \(value.currencyText)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(expirationText)
                .font(.caption.bold())
                .multilineTextAlignment(.trailing)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.orange.opacity(0.16), in: Capsule())
                .accessibilityIdentifier("RiskExpirationLabel")
        }
        .padding(.vertical, 5)
    }
}

enum FoodExpirationStyle {
    static func rowBackground(for item: FoodItem, on date: Date = Date(), calendar: Calendar = .current) -> Color {
        guard item.isActive else { return Color.clear }
        let daysLeft = item.daysUntilExpiration(on: date, calendar: calendar)

        if daysLeft < 0 {
            return Color.red.opacity(0.22)
        }
        if daysLeft <= 1 {
            return Color.red.opacity(0.18)
        }
        if daysLeft <= 3 {
            return Color.red.opacity(0.12)
        }
        if daysLeft <= 5 {
            return Color.orange.opacity(0.10)
        }
        return Color.clear
    }
}

struct ShoppingPanel: View {
    var suggestions: [ShoppingSuggestion]

    var body: some View {
        Panel(title: "Smart shopping") {
            if suggestions.isEmpty {
                Text("No shopping suggestions yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(suggestions) { suggestion in
                    HStack(alignment: .top, spacing: 10) {
                        FoodIconBadge(name: suggestion.name)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(suggestion.name).font(.headline)
                            Text("\(suggestion.priority.capitalized) priority · \(suggestion.reason)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

struct MealPanel: View {
    var meals: [MealIdea]

    var body: some View {
        Panel(title: "Meal ideas") {
            if meals.isEmpty {
                Text("Add foods to unlock local meal ideas.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(meals.prefix(4)) { meal in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(meal.name).font(.headline)
                            Spacer()
                            Text("\(meal.matchScore)%")
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.blue.opacity(0.12), in: Capsule())
                        }
                        Text("Use: \(meal.matched.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !meal.missing.isEmpty {
                            Text("Missing: \(meal.missing.joined(separator: ", "))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
        }
    }
}

struct MLReadinessPanel: View {
    var notes: [String]

    var body: some View {
        Panel(title: "On-device ML path") {
            ForEach(notes, id: \.self) { note in
                Label(note, systemImage: "cpu.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 2)
            }
        }
    }
}

struct Panel<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.bold())
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct FoodIconBadge: View {
    var icon: String
    var label: String
    var identifier: String

    init(item: FoodItem) {
        self.icon = item.icon
        self.label = item.name
        self.identifier = "FoodIcon-\(item.canonicalName)"
    }

    init(name: String) {
        let normalizedName = LocalFoodKnowledge.normalize(name)
            .replacingOccurrences(of: " ", with: "-")
        self.icon = LocalFoodKnowledge.icon(for: name)
        self.label = name.isEmpty ? "Food" : name
        self.identifier = "FoodIcon-\(normalizedName.isEmpty ? "unknown" : normalizedName)"
    }

    var body: some View {
        Text(icon)
            .font(.title3)
            .frame(width: 36, height: 36)
            .background(.green.opacity(0.12), in: Circle())
            .accessibilityLabel("\(label) icon")
            .accessibilityIdentifier(identifier)
    }
}

extension Double {
    var currencyText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? "$\(self.rounded(toPlaces: 2))"
    }
}

#Preview {
    ContentView()
        .environmentObject(LocalFoodStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("preview-pantree.json"), seedIfEmpty: true))
}
