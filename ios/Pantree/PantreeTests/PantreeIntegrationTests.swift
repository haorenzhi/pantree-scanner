import XCTest
@testable import Pantree

final class PantreeIntegrationTests: XCTestCase {
    func testReceiptToInventoryToAnalyticsFlow() throws {
        let store = LocalFoodStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)-integration.json"), seedIfEmpty: false)
        let result = ReceiptParser().parse(SampleData.sampleReceipt)
        try store.importReceipt(result)

        let summary = store.summary()
        XCTAssertEqual(summary.activeCount, 4)
        XCTAssertTrue(summary.categoryCounts[.produce, default: 0] >= 2)
        XCTAssertTrue(summary.mealIdeas.contains { $0.name == "Spinach Egg Scramble" })
    }

    func testPhotoPredictionCanLogConsumptionAndAffectShopping() throws {
        let store = LocalFoodStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)-photo-integration.json"), seedIfEmpty: false)
        let eggs = try store.add(LocalFoodKnowledge.makeFoodItem(name: "eggs", quantity: 1, source: "unit-test"))
        let predictions = LocalFoodPhotoPredictor().predict(from: [VisionLabel(identifier: "egg", confidence: 0.9)], inventory: store.items)

        XCTAssertEqual(predictions.first?.inventoryItemId, eggs.id)
        try store.consume(itemId: eggs.id, amount: 1, note: "photo integration")

        XCTAssertEqual(store.items.first?.section, .used)
        let suggestions = store.summary().shoppingSuggestions
        XCTAssertTrue(suggestions.contains { $0.name == "Eggs" })
    }
}
