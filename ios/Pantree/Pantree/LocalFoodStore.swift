import Combine
import Foundation

struct PantryStoreSnapshot: Codable, Equatable {
    var items: [FoodItem]
    var events: [FoodEvent]
    var mealRecords: [MealCalorieRecord]

    init(items: [FoodItem], events: [FoodEvent], mealRecords: [MealCalorieRecord] = []) {
        self.items = items
        self.events = events
        self.mealRecords = mealRecords
    }

    private enum CodingKeys: String, CodingKey {
        case items
        case events
        case mealRecords
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.items = try container.decode([FoodItem].self, forKey: .items)
        self.events = try container.decode([FoodEvent].self, forKey: .events)
        self.mealRecords = try container.decodeIfPresent([MealCalorieRecord].self, forKey: .mealRecords) ?? []
    }
}

enum LocalFoodStoreError: LocalizedError, Equatable {
    case foodNotFound
    case invalidAmount
    case persistenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .foodNotFound: return "Food item was not found."
        case .invalidAmount: return "Amount must be greater than zero."
        case .persistenceFailed(let reason): return "Could not save local pantry data: \(reason)"
        }
    }
}

final class LocalFoodStore: ObservableObject {
    @Published private(set) var items: [FoodItem]
    @Published private(set) var events: [FoodEvent]
    @Published private(set) var mealRecords: [MealCalorieRecord]

    let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL = LocalFoodStore.defaultFileURL(), seedIfEmpty: Bool = true) {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
        self.items = []
        self.events = []
        self.mealRecords = []

        do {
            try load()
            if seedIfEmpty && items.isEmpty {
                items = SampleData.initialInventory()
                try save()
            }
        } catch {
            items = seedIfEmpty ? SampleData.initialInventory() : []
            events = []
            mealRecords = []
            try? save()
        }
    }

    static func defaultFileURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        return documents.appendingPathComponent("pantree-local-store.json")
    }

    func summary(on date: Date = Date()) -> PantrySummary {
        FoodIntelligenceEngine().buildSummary(items: items, events: events, on: date)
    }

    @discardableResult
    func add(_ item: FoodItem) throws -> FoodItem {
        items.append(item)
        events.append(FoodEvent(type: .purchase, foodId: item.id, foodName: item.name, amount: item.quantity, unit: item.unit, source: item.source))
        try save()
        return item
    }

    @discardableResult
    func importReceipt(_ result: ReceiptParseResult) throws -> [FoodItem] {
        items.append(contentsOf: result.items)
        for item in result.items {
            events.append(FoodEvent(type: .purchase, foodId: item.id, foodName: item.name, amount: item.quantity, unit: item.unit, note: "Imported from receipt \(result.receiptId)", source: "receipt"))
        }
        try save()
        return result.items
    }

    @discardableResult
    func consume(itemId: UUID, amount: Double? = nil, note: String? = nil) throws -> FoodItem {
        try mutateQuantity(itemId: itemId, type: .consume, amount: amount, reason: nil, note: note)
    }

    @discardableResult
    func discard(itemId: UUID, reason: String? = "discarded") throws -> FoodItem {
        try mutateQuantity(itemId: itemId, type: .discard, amount: nil, reason: reason, note: nil)
    }

    @discardableResult
    func restock(itemId: UUID, amount: Double) throws -> FoodItem {
        guard amount > 0 else { throw LocalFoodStoreError.invalidAmount }
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { throw LocalFoodStoreError.foodNotFound }
        items[index].remainingQty += amount
        items[index].quantity = max(items[index].quantity, items[index].remainingQty)
        items[index].section = LocalFoodKnowledge.profile(for: items[index].canonicalName).section
        events.append(FoodEvent(type: .restock, foodId: itemId, foodName: items[index].name, amount: amount, unit: items[index].unit, source: "manual"))
        try save()
        return items[index]
    }

    @discardableResult
    func move(itemId: UUID, to section: StorageSection) throws -> FoodItem {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { throw LocalFoodStoreError.foodNotFound }
        items[index].section = section
        events.append(FoodEvent(type: .move, foodId: itemId, foodName: items[index].name, note: "Moved to \(section.title)", source: "manual"))
        try save()
        return items[index]
    }

    @discardableResult
    func markOpened(itemId: UUID, date: Date = Date()) throws -> FoodItem {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { throw LocalFoodStoreError.foodNotFound }
        items[index].openedAt = date
        events.append(FoodEvent(type: .open, foodId: itemId, foodName: items[index].name, source: "manual", createdAt: date))
        try save()
        return items[index]
    }

    @discardableResult
    func recordMealCalories(from predictions: [FoodPrediction], date: Date = Date(), source: String = "photo") throws -> MealCalorieRecord {
        let entries = predictions
            .filter { $0.estimatedCalories > 0 }
            .map { prediction in
                MealCalorieEntry(
                    foodName: prediction.foodName,
                    calories: prediction.estimatedCalories.rounded(toPlaces: 0),
                    confidence: prediction.confidence.rounded(toPlaces: 2)
                )
            }
        guard !entries.isEmpty else { throw LocalFoodStoreError.invalidAmount }

        let record = MealCalorieRecord(createdAt: date, entries: entries, source: source)
        mealRecords.append(record)
        try save()
        return record
    }

    func dailyCalories(on date: Date = Date(), calendar: Calendar = .current) -> Double {
        mealRecords
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .map(\.totalCalories)
            .reduce(0, +)
            .rounded(toPlaces: 0)
    }

    func reset(items: [FoodItem] = SampleData.initialInventory(), events: [FoodEvent] = [], mealRecords: [MealCalorieRecord] = []) throws {
        self.items = items
        self.events = events
        self.mealRecords = mealRecords
        try save()
    }

    func load() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let data = try Data(contentsOf: fileURL)
        let snapshot = try decoder.decode(PantryStoreSnapshot.self, from: data)
        items = snapshot.items
        events = snapshot.events
        mealRecords = snapshot.mealRecords
    }

    func save() throws {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try encoder.encode(PantryStoreSnapshot(items: items, events: events, mealRecords: mealRecords))
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            throw LocalFoodStoreError.persistenceFailed(error.localizedDescription)
        }
    }

    private func mutateQuantity(itemId: UUID, type: FoodEventType, amount: Double?, reason: String?, note: String?) throws -> FoodItem {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { throw LocalFoodStoreError.foodNotFound }
        let selectedAmount = amount ?? items[index].remainingQty
        guard selectedAmount > 0 else { throw LocalFoodStoreError.invalidAmount }
        let appliedAmount = min(items[index].remainingQty, selectedAmount)
        items[index].remainingQty = max(0, items[index].remainingQty - appliedAmount)
        if items[index].remainingQty == 0 {
            items[index].section = .used
        }
        events.append(FoodEvent(type: type, foodId: itemId, foodName: items[index].name, amount: appliedAmount, unit: items[index].unit, reason: reason, note: note, source: "manual"))
        try save()
        return items[index]
    }
}
