import SwiftUI

struct InventoryView: View {
    @EnvironmentObject private var store: LocalFoodStore
    @State private var showingAddFood = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(StorageSection.allCases.filter { $0 != .used }) { section in
                    let foods = store.items.filter { $0.section == section && $0.isActive }
                    if !foods.isEmpty {
                        Section(section.title) {
                            ForEach(foods) { item in
                                FoodItemRow(item: item)
                            }
                        }
                    }
                }

                let usedFoods = store.items.filter { $0.section == .used || !$0.isActive }
                if !usedFoods.isEmpty {
                    Section("Used / history") {
                        ForEach(usedFoods.prefix(8)) { item in
                            FoodItemRow(item: item, showActions: false)
                        }
                    }
                }
            }
            .overlay {
                if store.items.filter(\.isActive).isEmpty {
                    ContentUnavailableView("No active foods", systemImage: "refrigerator", description: Text("Add food manually or import a receipt."))
                }
            }
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
}

struct FoodItemRow: View {
    @EnvironmentObject private var store: LocalFoodStore
    var item: FoodItem
    var showActions = true

    var body: some View {
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
                    Button("Ate") { _ = try? store.consume(itemId: item.id) }
                        .buttonStyle(.borderedProminent)
                    Button("Open") { _ = try? store.markOpened(itemId: item.id) }
                        .buttonStyle(.bordered)
                    Button("Discard") { _ = try? store.discard(itemId: item.id) }
                        .buttonStyle(.bordered)
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
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
