import Foundation
#if canImport(UIKit)
import UIKit
#endif

protocol FoodPhotoPredicting {
    func predict(from labels: [VisionLabel], inventory: [FoodItem]) -> [FoodPrediction]
}

struct LocalFoodPhotoPredictor: FoodPhotoPredicting, Sendable {
    func predict(from labels: [VisionLabel], inventory: [FoodItem]) -> [FoodPrediction] {
        let activeInventory = inventory.filter(\.isActive)
        let predictions = labels
            .filter { $0.confidence >= 0.2 }
            .flatMap { predictionCandidates(for: $0, inventory: activeInventory) }
            .sorted { $0.confidence > $1.confidence }

        return deduplicate(predictions).prefix(5).map { $0 }
    }

    func sampleMealLabels() -> [VisionLabel] {
        [
            VisionLabel(identifier: "spinach", confidence: 0.86),
            VisionLabel(identifier: "egg", confidence: 0.82),
            VisionLabel(identifier: "toast", confidence: 0.58)
        ]
    }

    func sampleFridgeLabels() -> [VisionLabel] {
        [
            VisionLabel(identifier: "milk", confidence: 0.88),
            VisionLabel(identifier: "yogurt", confidence: 0.72),
            VisionLabel(identifier: "berries", confidence: 0.67)
        ]
    }

    private func predictionCandidates(for label: VisionLabel, inventory: [FoodItem]) -> [FoodPrediction] {
        let profile = LocalFoodKnowledge.profile(for: label.identifier)
        let matchedItem = inventory.first { item in
            item.canonicalName == profile.canonicalName || LocalFoodKnowledge.normalize(item.name).contains(LocalFoodKnowledge.normalize(label.identifier))
        }
        let calories = estimatedCalories(profile: profile, matchedItem: matchedItem)

        if profile.category == .unknown {
            return inventory
                .filter { item in LocalFoodKnowledge.normalize(label.identifier).contains(LocalFoodKnowledge.normalize(item.name)) }
                .map { item in
                    FoodPrediction(
                        foodName: item.name,
                        inventoryItemId: item.id,
                        confidence: min(0.95, label.confidence * 0.75),
                        estimatedCalories: estimatedCalories(profile: LocalFoodKnowledge.profile(for: item.canonicalName), matchedItem: item),
                        reason: "Matched the camera label to an existing pantry item."
                    )
                }
        }

        return [
            FoodPrediction(
                foodName: profile.canonicalName.titleCasedFoodName,
                inventoryItemId: matchedItem?.id,
                confidence: min(0.98, label.confidence * (matchedItem == nil ? 0.82 : 0.95)),
                estimatedCalories: calories,
                reason: matchedItem == nil
                    ? "Recognized locally from the static food cache; confirm before logging."
                    : "Recognized locally and matched to current inventory."
            )
        ]
    }

    private func estimatedCalories(profile: FoodProfile, matchedItem: FoodItem?) -> Double {
        if let itemCalories = matchedItem?.nutrition.calories, itemCalories > 0 {
            return itemCalories.rounded(toPlaces: 0)
        }
        if profile.nutrition.calories > 0 {
            return profile.nutrition.calories.rounded(toPlaces: 0)
        }

        switch profile.category {
        case .produce: return 70
        case .protein: return 180
        case .dairy: return 140
        case .grain: return 180
        case .pantry: return 120
        case .treat: return 220
        case .unknown: return 180
        }
    }

    private func deduplicate(_ predictions: [FoodPrediction]) -> [FoodPrediction] {
        var seen = Set<String>()
        var result: [FoodPrediction] = []
        for prediction in predictions {
            let key = prediction.foodName.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(prediction)
        }
        return result
    }
}

#if canImport(UIKit)
protocol FoodImageLabeling {
    func labels(for image: UIImage) async -> [VisionLabel]
}

struct LocalHeuristicImageLabeler: FoodImageLabeling {
    func labels(for image: UIImage) async -> [VisionLabel] {
        // Privacy-first POC: deterministic local labels until a bundled Core ML model is added.
        // The app never uploads the captured image.
        [
            VisionLabel(identifier: "spinach", confidence: 0.62),
            VisionLabel(identifier: "eggs", confidence: 0.56)
        ]
    }
}
#endif
