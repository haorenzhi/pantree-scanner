import Foundation

struct LocalRecipe: Equatable, Sendable {
    var id: String
    var name: String
    var ingredients: [String]
    var minutes: Int
    var healthGoal: String
}

enum LocalFoodKnowledge {
    static let profiles: [String: FoodProfile] = [
        "apples": FoodProfile(canonicalName: "apples", aliases: ["apple"], category: .produce, section: .fridge, shelfLifeDays: 21, defaultUnit: "item", defaultQuantity: 1, nutrition: NutritionFacts(calories: 95, protein: 0.5, carbs: 25, fat: 0.3, fiber: 4.4), perishable: true),
        "bananas": FoodProfile(canonicalName: "bananas", aliases: ["banana"], category: .produce, section: .shelf, shelfLifeDays: 7, defaultUnit: "item", defaultQuantity: 1, nutrition: NutritionFacts(calories: 105, protein: 1.3, carbs: 27, fat: 0.4, fiber: 3.1), perishable: true),
        "blueberries": FoodProfile(canonicalName: "blueberries", aliases: ["blueberry"], category: .produce, section: .fridge, shelfLifeDays: 7, defaultUnit: "cup", defaultQuantity: 1, nutrition: NutritionFacts(calories: 84, protein: 1.1, carbs: 21, fat: 0.5, fiber: 3.6), perishable: true),
        "strawberries": FoodProfile(canonicalName: "strawberries", aliases: ["strawberry"], category: .produce, section: .fridge, shelfLifeDays: 5, defaultUnit: "cup", defaultQuantity: 1, nutrition: NutritionFacts(calories: 49, protein: 1, carbs: 12, fat: 0.5, fiber: 3), perishable: true),
        "grapefruit": FoodProfile(canonicalName: "grapefruit", aliases: ["grapefruits"], category: .produce, section: .fridge, shelfLifeDays: 21, defaultUnit: "item", defaultQuantity: 1, nutrition: NutritionFacts(calories: 52, protein: 0.9, carbs: 13, fat: 0.2, fiber: 2), perishable: true),
        "spinach": FoodProfile(canonicalName: "spinach", aliases: ["baby spinach"], category: .produce, section: .fridge, shelfLifeDays: 5, defaultUnit: "bag", defaultQuantity: 1, nutrition: NutritionFacts(calories: 14, protein: 1.7, carbs: 2.2, fat: 0.2, fiber: 1.4), perishable: true),
        "broccoli": FoodProfile(canonicalName: "broccoli", aliases: ["broccoli crown"], category: .produce, section: .fridge, shelfLifeDays: 7, defaultUnit: "head", defaultQuantity: 1, nutrition: NutritionFacts(calories: 31, protein: 2.5, carbs: 6, fat: 0.3, fiber: 2.4), perishable: true),
        "lettuce": FoodProfile(canonicalName: "lettuce", aliases: ["romaine", "greens"], category: .produce, section: .fridge, shelfLifeDays: 5, defaultUnit: "head", defaultQuantity: 1, nutrition: NutritionFacts(calories: 16, protein: 1, carbs: 3, fat: 0.2, fiber: 2), perishable: true),
        "tomatoes": FoodProfile(canonicalName: "tomatoes", aliases: ["tomato"], category: .produce, section: .fridge, shelfLifeDays: 7, defaultUnit: "item", defaultQuantity: 1, nutrition: NutritionFacts(calories: 22, protein: 1.1, carbs: 4.8, fat: 0.2, fiber: 1.5), perishable: true),
        "carrots": FoodProfile(canonicalName: "carrots", aliases: ["carrot"], category: .produce, section: .fridge, shelfLifeDays: 21, defaultUnit: "bag", defaultQuantity: 1, nutrition: NutritionFacts(calories: 52, protein: 1.2, carbs: 12, fat: 0.3, fiber: 3.6), perishable: true),
        "milk": FoodProfile(canonicalName: "milk", aliases: ["whole milk", "2 milk", "almond milk", "oat milk"], category: .dairy, section: .fridge, shelfLifeDays: 7, defaultUnit: "carton", defaultQuantity: 1, nutrition: NutritionFacts(calories: 149, protein: 7.7, carbs: 12, fat: 8, fiber: 0), perishable: true),
        "eggs": FoodProfile(canonicalName: "eggs", aliases: ["egg", "large eggs"], category: .protein, section: .fridge, shelfLifeDays: 35, defaultUnit: "count", defaultQuantity: 12, nutrition: NutritionFacts(calories: 72, protein: 6.3, carbs: 0.4, fat: 4.8, fiber: 0), perishable: true),
        "yogurt": FoodProfile(canonicalName: "yogurt", aliases: ["greek yogurt", "honey yogurt", "honey yoghurt"], category: .dairy, section: .fridge, shelfLifeDays: 14, defaultUnit: "container", defaultQuantity: 1, nutrition: NutritionFacts(calories: 120, protein: 12, carbs: 9, fat: 4, fiber: 0), perishable: true),
        "cheese": FoodProfile(canonicalName: "cheese", aliases: ["cheddar cheese", "mozzarella", "swiss cheese"], category: .dairy, section: .fridge, shelfLifeDays: 21, defaultUnit: "pack", defaultQuantity: 1, nutrition: NutritionFacts(calories: 113, protein: 7, carbs: 0.4, fat: 9, fiber: 0), perishable: true),
        "chicken": FoodProfile(canonicalName: "chicken", aliases: ["chicken breast", "chicken thighs", "fried chicken"], category: .protein, section: .freezer, shelfLifeDays: 270, defaultUnit: "lb", defaultQuantity: 1, nutrition: NutritionFacts(calories: 187, protein: 35, carbs: 0, fat: 4, fiber: 0), perishable: true),
        "salmon": FoodProfile(canonicalName: "salmon", aliases: ["fish", "fillet"], category: .protein, section: .freezer, shelfLifeDays: 180, defaultUnit: "lb", defaultQuantity: 1, nutrition: NutritionFacts(calories: 233, protein: 25, carbs: 0, fat: 14, fiber: 0), perishable: true),
        "beef": FoodProfile(canonicalName: "beef", aliases: ["ground beef", "steak"], category: .protein, section: .freezer, shelfLifeDays: 180, defaultUnit: "lb", defaultQuantity: 1, nutrition: NutritionFacts(calories: 287, protein: 23, carbs: 0, fat: 21, fiber: 0), perishable: true),
        "tofu": FoodProfile(canonicalName: "tofu", aliases: ["firm tofu"], category: .protein, section: .fridge, shelfLifeDays: 14, defaultUnit: "block", defaultQuantity: 1, nutrition: NutritionFacts(calories: 80, protein: 8, carbs: 2, fat: 4, fiber: 1), perishable: true),
        "bread": FoodProfile(canonicalName: "bread", aliases: ["sliced bread", "loaf", "baguette", "white baguette"], category: .grain, section: .shelf, shelfLifeDays: 5, defaultUnit: "loaf", defaultQuantity: 1, nutrition: NutritionFacts(calories: 80, protein: 3, carbs: 15, fat: 1, fiber: 1), perishable: true),
        "rice": FoodProfile(canonicalName: "rice", aliases: ["white rice", "brown rice"], category: .grain, section: .shelf, shelfLifeDays: 365, defaultUnit: "bag", defaultQuantity: 1, nutrition: NutritionFacts(calories: 170, protein: 3, carbs: 37, fat: 1, fiber: 1), perishable: false),
        "pasta": FoodProfile(canonicalName: "pasta", aliases: ["spaghetti", "noodles"], category: .grain, section: .shelf, shelfLifeDays: 365, defaultUnit: "box", defaultQuantity: 1, nutrition: NutritionFacts(calories: 200, protein: 7, carbs: 42, fat: 1, fiber: 2), perishable: false),
        "beans": FoodProfile(canonicalName: "beans", aliases: ["black beans", "kidney beans"], category: .protein, section: .shelf, shelfLifeDays: 365, defaultUnit: "can", defaultQuantity: 1, nutrition: NutritionFacts(calories: 110, protein: 7, carbs: 20, fat: 0.5, fiber: 7), perishable: false),
        "cereal": FoodProfile(canonicalName: "cereal", aliases: ["granola"], category: .grain, section: .shelf, shelfLifeDays: 180, defaultUnit: "box", defaultQuantity: 1, nutrition: NutritionFacts(calories: 160, protein: 4, carbs: 34, fat: 2, fiber: 3), perishable: false),
        "chips": FoodProfile(canonicalName: "chips", aliases: ["potato chips", "corn chips", "salted corn chips", "snack"], category: .treat, section: .shelf, shelfLifeDays: 60, defaultUnit: "bag", defaultQuantity: 1, nutrition: NutritionFacts(calories: 150, protein: 2, carbs: 15, fat: 10, fiber: 1), perishable: false),
        "salsa": FoodProfile(canonicalName: "salsa", aliases: ["chunky salsa"], category: .pantry, section: .fridge, shelfLifeDays: 30, defaultUnit: "jar", defaultQuantity: 1, nutrition: NutritionFacts(calories: 10, protein: 0.5, carbs: 2, fat: 0, fiber: 0.5), perishable: true),
        "peanut butter": FoodProfile(canonicalName: "peanut butter", aliases: ["peanut butter balls"], category: .pantry, section: .shelf, shelfLifeDays: 180, defaultUnit: "pack", defaultQuantity: 1, nutrition: NutritionFacts(calories: 190, protein: 7, carbs: 7, fat: 16, fiber: 2), perishable: false)
    ]

    static let recipes: [LocalRecipe] = [
        LocalRecipe(id: "spinach-egg-scramble", name: "Spinach Egg Scramble", ingredients: ["eggs", "spinach", "cheese"], minutes: 12, healthGoal: "protein + greens"),
        LocalRecipe(id: "chicken-rice-bowl", name: "Chicken Rice Bowl", ingredients: ["chicken", "rice", "broccoli", "carrots"], minutes: 25, healthGoal: "balanced dinner"),
        LocalRecipe(id: "salmon-salad", name: "Salmon Salad", ingredients: ["salmon", "lettuce", "tomatoes"], minutes: 18, healthGoal: "omega-3 + vegetables"),
        LocalRecipe(id: "fruit-yogurt-bowl", name: "Fruit Yogurt Bowl", ingredients: ["yogurt", "blueberries", "strawberries", "bananas"], minutes: 5, healthGoal: "quick breakfast"),
        LocalRecipe(id: "bean-pasta", name: "Bean Pasta", ingredients: ["beans", "pasta", "tomatoes", "cheese"], minutes: 20, healthGoal: "pantry protein"),
        LocalRecipe(id: "toast-eggs-fruit", name: "Toast, Eggs, and Fruit", ingredients: ["bread", "eggs", "apples"], minutes: 10, healthGoal: "simple breakfast")
    ]

    static func normalize(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9\\s-]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func profile(for name: String) -> FoodProfile {
        let normalized = normalize(name)
        if let exact = profiles[normalized] {
            return exact
        }

        for (key, profile) in profiles {
            if normalized.contains(key) || key.contains(normalized) {
                return profile
            }
            if profile.aliases.contains(where: { alias in
                let normalizedAlias = normalize(alias)
                return normalized.contains(normalizedAlias) || normalizedAlias.contains(normalized)
            }) {
                return profile
            }
        }

        return FoodProfile(
            canonicalName: normalized.isEmpty ? "unknown" : normalized,
            aliases: [],
            category: .unknown,
            section: .fridge,
            shelfLifeDays: 7,
            defaultUnit: "item",
            defaultQuantity: 1,
            nutrition: .empty,
            perishable: true
        )
    }

    static func makeFoodItem(
        name: String,
        buyDate: Date = Date(),
        price: Double? = nil,
        quantity: Double? = nil,
        source: String,
        calendar: Calendar = .current
    ) -> FoodItem {
        let profile = profile(for: name)
        let expDate = calendar.date(byAdding: .day, value: profile.shelfLifeDays, to: buyDate) ?? buyDate
        let finalQuantity = quantity ?? profile.defaultQuantity
        return FoodItem(
            name: name.titleCasedFoodName,
            canonicalName: profile.canonicalName,
            category: profile.category,
            section: profile.section,
            buyDate: buyDate,
            expDate: expDate,
            price: price,
            quantity: finalQuantity,
            unit: profile.defaultUnit,
            source: source,
            confidence: profile.category == .unknown ? 0.45 : 0.9,
            nutrition: profile.nutrition
        )
    }
}

extension String {
    var titleCasedFoodName: String {
        split(separator: " ")
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }
}
