import SwiftUI

struct InventoryView: View {
    @EnvironmentObject private var store: LocalFoodStore
    @State private var showingAddFood = false
    @State private var collapsedSections: Set<StorageSection> = [.used]

    private var activeItems: [FoodItem] {
        store.items.filter(\.isActive)
    }

    private var usedFoods: [FoodItem] {
        store.items.filter { $0.section == .used || !$0.isActive }
    }

    private var activeSections: [StorageSection] {
        StorageSection.allCases.filter { $0 != .used }
    }

    private var historyListHeight: CGFloat {
        let rowCount = collapsedSections.contains(.used) ? 0 : min(usedFoods.count, 8)
        return min(360, CGFloat(96 + rowCount * 72))
    }

    var body: some View {
        NavigationStack {
            inventoryContent
            .navigationTitle("Inventory")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddFood = true
                    } label: {
                        Label("Add Food", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddFood) {
                AddFoodView()
            }
        }
    }

    @ViewBuilder
    private var inventoryContent: some View {
        if activeItems.isEmpty {
            VStack(spacing: 0) {
                ContentUnavailableView("No active foods", systemImage: "refrigerator", description: Text("Add food manually or import a receipt."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if !usedFoods.isEmpty {
                    List {
                        usedHistorySection
                    }
                    .listStyle(.insetGrouped)
                    .frame(height: historyListHeight)
                }
            }
        } else {
            List {
                ForEach(activeSections) { section in
                    let foods = activeItems.filter { $0.section == section }
                    if !foods.isEmpty {
                        activeFoodSection(section, foods: foods)
                    }
                }

                usedHistorySection
            }
            .listStyle(.insetGrouped)
        }
    }

    @ViewBuilder
    private func activeFoodSection(_ section: StorageSection, foods: [FoodItem]) -> some View {
        Section {
            if !collapsedSections.contains(section) {
                ForEach(foods) { item in
                    FoodItemRow(item: item)
                        .listRowBackground(FoodExpirationStyle.rowBackground(for: item))
                }
            }
        } header: {
            CollapsibleSectionHeader(title: section.title, count: foods.count, isCollapsed: collapsedSections.contains(section)) {
                toggle(section)
            }
        }
    }

    @ViewBuilder
    private var usedHistorySection: some View {
        if !usedFoods.isEmpty {
            Section {
                if !collapsedSections.contains(.used) {
                    ForEach(usedFoods.prefix(8)) { item in
                        FoodItemRow(item: item, showActions: false)
                            .listRowBackground(Color.clear)
                    }
                }
            } header: {
                CollapsibleSectionHeader(title: "Used / history", count: usedFoods.count, isCollapsed: collapsedSections.contains(.used)) {
                    toggle(.used)
                }
            }
        }
    }

    private func toggle(_ section: StorageSection) {
        if collapsedSections.contains(section) {
            collapsedSections.remove(section)
        } else {
            collapsedSections.insert(section)
        }
    }
}

struct CollapsibleSectionHeader: View {
    var title: String
    var count: Int
    var isCollapsed: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.caption.bold())
                Text("\(count)")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.12), in: Capsule())
                Spacer()
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.caption.bold())
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("InventorySectionHeader-\(title.replacingOccurrences(of: " ", with: "-"))")
    }
}

struct FoodItemRow: View {
    @EnvironmentObject private var store: LocalFoodStore
    var item: FoodItem
    var showActions = true

    var body: some View {
        rowContent
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                if showActions {
                    Button {
                        _ = try? store.consume(itemId: item.id)
                    } label: {
                        Label("Ate", systemImage: "fork.knife")
                    }
                    .tint(.green)
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                if showActions {
                    Button(role: .destructive) {
                        _ = try? store.discard(itemId: item.id)
                    } label: {
                        Label("Discard", systemImage: "trash")
                    }
                    .tint(.red)
                }
            }
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                FoodIconBadge(item: item)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name).font(.headline)
                    Text("\(item.category.title) · \(item.remainingQty.cleanText) / \(item.quantity.cleanText) \(item.unit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(item.section.title).font(.caption.bold())
                    Text(item.expDate, format: .dateTime.month().day())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if showActions {
                HStack {
                    Button("Open") { _ = try? store.markOpened(itemId: item.id) }
                        .buttonStyle(.bordered)
                    Text("Swipe left to eat · swipe right to discard")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        }
    }
}

struct AddFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LocalFoodStore
    @State private var name = ""
    @State private var price = ""
    @State private var quantity = ""
    @State private var errorMessage: String?
    @FocusState private var focusedField: AddFoodField?

    private enum AddFoodField: Hashable {
        case name
        case price
        case quantity
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Food name", text: $name)
                        .focused($focusedField, equals: .name)
                    TextField("Price (optional)", text: $price)
                        .focused($focusedField, equals: .price)
                        .keyboardType(.decimalPad)
                    TextField("Quantity (optional)", text: $quantity)
                        .focused($focusedField, equals: .quantity)
                        .keyboardType(.decimalPad)
                }
                Section("Local prediction") {
                    let profile = LocalFoodKnowledge.profile(for: name)
                    LabeledContent("Icon") {
                        FoodIconBadge(name: name)
                    }
                    LabeledContent("Category", value: profile.category.title)
                    LabeledContent("Default storage", value: profile.section.title)
                    LabeledContent("Predicted shelf life", value: "\(profile.shelfLifeDays) days")
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Add Food")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveFood() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                    .accessibilityIdentifier("DismissAddFoodKeyboardButton")
                }
            }
        }
    }

    private func saveFood() {
        do {
            let item = LocalFoodKnowledge.makeFoodItem(
                name: name,
                price: Double(price),
                quantity: Double(quantity),
                source: "manual"
            )
            try store.add(item)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension Double {
    var cleanText: String {
        if rounded() == self {
            return String(Int(self))
        }
        return String(format: "%.2f", self)
    }
}
