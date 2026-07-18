import Foundation

enum StorageSection: String, Codable, CaseIterable, Identifiable {
    case fridge
    case freezer
    case shelf
    case used

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fridge: return "Fridge"
        case .freezer: return "Freezer"
        case .shelf: return "Shelf"
        case .used: return "Used"
        }
    }
}

enum FoodCategory: String, Codable, CaseIterable, Identifiable {
    case produce
    case protein
    case dairy
    case grain
    case pantry
    case treat
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .produce: return "Produce"
        case .protein: return "Protein"
        case .dairy: return "Dairy"
        case .grain: return "Grain"
        case .pantry: return "Pantry"
        case .treat: return "Treat"
        case .unknown: return "Unknown"
        }
    }
}

enum FoodEventType: String, Codable, CaseIterable, Identifiable {
    case purchase
    case consume
    case discard
    case open
    case move
    case restock
    case edit

    var id: String { rawValue }
}

struct NutritionFacts: Codable, Equatable, Sendable {
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double

    static let empty = NutritionFacts(calories: 0, protein: 0, carbs: 0, fat: 0, fiber: 0)
}

struct FoodProfile: Codable, Equatable, Sendable {
    var canonicalName: String
    var aliases: [String]
    var category: FoodCategory
    var section: StorageSection
    var shelfLifeDays: Int
    var defaultUnit: String
    var defaultQuantity: Double
    var nutrition: NutritionFacts
    var perishable: Bool
}

struct FoodItem: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var canonicalName: String
    var category: FoodCategory
    var section: StorageSection
    var buyDate: Date
    var expDate: Date
    var openedAt: Date?
    var price: Double?
    var quantity: Double
    var unit: String
    var remainingQty: Double
    var source: String
    var confidence: Double
    var nutrition: NutritionFacts
    var barcode: String?
    var store: String?
    var receiptId: String?

    init(
        id: UUID = UUID(),
        name: String,
        canonicalName: String,
        category: FoodCategory,
        section: StorageSection,
        buyDate: Date,
        expDate: Date,
        openedAt: Date? = nil,
        price: Double? = nil,
        quantity: Double,
        unit: String,
        remainingQty: Double? = nil,
        source: String,
        confidence: Double = 1.0,
        nutrition: NutritionFacts = .empty,
        barcode: String? = nil,
        store: String? = nil,
        receiptId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.canonicalName = canonicalName
        self.category = category
        self.section = section
        self.buyDate = buyDate
        self.expDate = expDate
        self.openedAt = openedAt
        self.price = price
        self.quantity = quantity
        self.unit = unit
        self.remainingQty = remainingQty ?? quantity
        self.source = source
        self.confidence = confidence
        self.nutrition = nutrition
        self.barcode = barcode
        self.store = store
        self.receiptId = receiptId
    }

    var isActive: Bool {
        section != .used && remainingQty > 0
    }

    func daysUntilExpiration(on date: Date = Date(), calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: date)
        let end = calendar.startOfDay(for: expDate)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    func remainingShare() -> Double {
        guard quantity > 0 else { return 0 }
        return min(1, max(0, remainingQty / quantity))
    }

    func estimatedRemainingValue() -> Double? {
        guard let price else { return nil }
        return (price * remainingShare()).rounded(toPlaces: 2)
    }
}

struct FoodEvent: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var type: FoodEventType
    var foodId: UUID?
    var foodName: String
    var amount: Double?
    var unit: String?
    var reason: String?
    var note: String?
    var source: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        type: FoodEventType,
        foodId: UUID? = nil,
        foodName: String,
        amount: Double? = nil,
        unit: String? = nil,
        reason: String? = nil,
        note: String? = nil,
        source: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.foodId = foodId
        self.foodName = foodName
        self.amount = amount
        self.unit = unit
        self.reason = reason
        self.note = note
        self.source = source
        self.createdAt = createdAt
    }
}

struct ExpiryRisk: Identifiable, Equatable {
    var id: UUID
    var item: FoodItem
    var score: Int
    var reason: String
    var daysLeft: Int
    var valueAtRisk: Double?
}

struct HealthBalance: Equatable {
    var score: Int
    var produceShare: Double
    var proteinShare: Double
    var treatShare: Double
    var insights: [String]
}

struct ShoppingSuggestion: Identifiable, Equatable {
    var id = UUID()
    var name: String
    var reason: String
    var priority: String
}

struct MealIdea: Identifiable, Equatable {
    var id: String
    var name: String
    var ingredients: [String]
    var matched: [String]
    var missing: [String]
    var expiringMatches: [String]
    var minutes: Int
    var healthGoal: String
    var matchScore: Int
}

struct FoodPrediction: Identifiable, Equatable {
    var id = UUID()
    var foodName: String
    var inventoryItemId: UUID?
    var confidence: Double
    var estimatedCalories: Double = 0
    var reason: String
}

struct MealCalorieEntry: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var foodName: String
    var calories: Double
    var confidence: Double
}

struct MealCalorieRecord: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var createdAt: Date
    var entries: [MealCalorieEntry]
    var source: String

    var totalCalories: Double {
        entries.map(\.calories).reduce(0, +).rounded(toPlaces: 0)
    }
}

struct VisionLabel: Equatable, Sendable {
    var identifier: String
    var confidence: Double
}

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
