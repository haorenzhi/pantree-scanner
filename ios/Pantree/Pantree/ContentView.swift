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
                .tabItem { Label("Photo", systemImage: "camera.viewfinder") }
        }
        .accessibilityIdentifier("PantreeRoot")
    }
}

struct DashboardView: View {
    @EnvironmentObject private var store: LocalFoodStore

    var summary: PantrySummary { store.summary() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PrivacyBanner()
                    MetricGrid(summary: summary)
                    HealthPanel(balance: summary.healthBalance)
                    RiskPanel(risks: summary.expiryRisks)
                    ShoppingPanel(suggestions: summary.shoppingSuggestions)
                    MealPanel(meals: summary.mealIdeas)
                    MLReadinessPanel(notes: summary.mlReadiness)
                }
                .padding()
            }
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
            MetricCard(title: "Active foods", value: "\(summary.activeCount)", detail: "\(summary.totalCount) total")
            MetricCard(title: "Health score", value: "\(summary.healthBalance.score)", detail: "local heuristic")
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
    var balance: HealthBalance

    var body: some View {
        Panel(title: "Diet balance") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Produce \((balance.produceShare * 100).rounded(toPlaces: 0), specifier: "%.0f")% · Protein \((balance.proteinShare * 100).rounded(toPlaces: 0), specifier: "%.0f")% · Treats \((balance.treatShare * 100).rounded(toPlaces: 0), specifier: "%.0f")%")
                    .font(.subheadline)
                ForEach(balance.insights, id: \.self) { insight in
                    Label(insight, systemImage: "leaf.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct RiskPanel: View {
    @EnvironmentObject private var store: LocalFoodStore
    var risks: [ExpiryRisk]

    var body: some View {
        Panel(title: "Eat first") {
            if risks.isEmpty {
                Text("No urgent expiration risk right now.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(risks.prefix(5)) { risk in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(risk.item.name).font(.headline)
                                    Text(risk.reason).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(risk.score)")
                                    .font(.headline.monospacedDigit())
                            }
                            HStack {
                                Button("Ate") { _ = try? store.consume(itemId: risk.item.id) }
                                    .buttonStyle(.borderedProminent)
                                Button("Discard") { _ = try? store.discard(itemId: risk.item.id) }
                                    .buttonStyle(.bordered)
                                Spacer()
                                if let value = risk.valueAtRisk {
                                    Text(value.currencyText).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
        }
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
                    VStack(alignment: .leading, spacing: 3) {
                        Text(suggestion.name).font(.headline)
                        Text("\(suggestion.priority.capitalized) priority · \(suggestion.reason)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
