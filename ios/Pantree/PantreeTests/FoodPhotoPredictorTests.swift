import XCTest
@testable import Pantree

final class FoodPhotoPredictorTests: XCTestCase {
    func testPredictorMatchesLabelsToInventory() {
        let inventory = [
            LocalFoodKnowledge.makeFoodItem(name: "spinach", source: "unit-test"),
            LocalFoodKnowledge.makeFoodItem(name: "eggs", source: "unit-test")
        ]
        let predictions = LocalFoodPhotoPredictor().predict(
            from: [VisionLabel(identifier: "baby spinach", confidence: 0.9)],
            inventory: inventory
        )

        XCTAssertEqual(predictions.first?.foodName, "Spinach")
        XCTAssertEqual(predictions.first?.inventoryItemId, inventory[0].id)
        XCTAssertGreaterThan(predictions.first?.confidence ?? 0, 0.8)
    }

    func testPredictorDeduplicatesAndLimitsLowConfidenceLabels() {
        let predictions = LocalFoodPhotoPredictor().predict(
            from: [
                VisionLabel(identifier: "egg", confidence: 0.91),
                VisionLabel(identifier: "eggs", confidence: 0.72),
                VisionLabel(identifier: "noise", confidence: 0.1)
            ],
            inventory: []
        )

        XCTAssertEqual(predictions.count, 1)
        XCTAssertEqual(predictions[0].foodName, "Eggs")
    }
}
