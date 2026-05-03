import XCTest
@testable import Pantree

final class LocalFoodStoreTests: XCTestCase {
    private func tempURL(_ name: String = UUID().uuidString) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("\(name)-pantree-store.json")
    }

    func testStorePersistsAddedFoodAndEvents() throws {
        let url = tempURL()
        let store = LocalFoodStore(fileURL: url, seedIfEmpty: false)
        let item = LocalFoodKnowledge.makeFoodItem(name: "eggs", price: 4.99, quantity: 12, source: "unit-test")
        try store.add(item)

        let reloaded = LocalFoodStore(fileURL: url, seedIfEmpty: false)
        XCTAssertEqual(reloaded.items.count, 1)
        XCTAssertEqual(reloaded.events.count, 1)
        XCTAssertEqual(reloaded.items[0].canonicalName, "eggs")
        try? FileManager.default.removeItem(at: url)
    }

    func testConsumeAndDiscardUpdateInventoryLocally() throws {
        let store = LocalFoodStore(fileURL: tempURL(), seedIfEmpty: false)
        let eggs = try store.add(LocalFoodKnowledge.makeFoodItem(name: "eggs", quantity: 2, source: "unit-test"))

        let afterOne = try store.consume(itemId: eggs.id, amount: 1)
        XCTAssertEqual(afterOne.remainingQty, 1)
        XCTAssertEqual(afterOne.section, .fridge)

        let afterDiscard = try store.discard(itemId: eggs.id)
        XCTAssertEqual(afterDiscard.remainingQty, 0)
        XCTAssertEqual(afterDiscard.section, .used)
        XCTAssertEqual(store.events.filter { $0.type == .consume }.count, 1)
        XCTAssertEqual(store.events.filter { $0.type == .discard }.count, 1)
    }

    func testImportReceiptAddsPurchaseEvents() throws {
        let store = LocalFoodStore(fileURL: tempURL(), seedIfEmpty: false)
        let result = ReceiptParser().parse("EGGS 4.99\nMILK 3.99")
        let imported = try store.importReceipt(result)

        XCTAssertEqual(imported.count, 2)
        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(store.events.filter { $0.type == .purchase }.count, 2)
        XCTAssertEqual(store.summary().activeCount, 2)
    }

    func testMealCalorieRecordsPersistAndSumDaily() throws {
        let url = tempURL()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let breakfast = ISO8601DateFormatter().date(from: "2026-05-03T08:30:00Z")!
        let dinner = ISO8601DateFormatter().date(from: "2026-05-03T19:00:00Z")!
        let nextDay = ISO8601DateFormatter().date(from: "2026-05-04T08:30:00Z")!

        let store = LocalFoodStore(fileURL: url, seedIfEmpty: false)
        let firstRecord = try store.recordMealCalories(
            from: [FoodPrediction(foodName: "Eggs", inventoryItemId: nil, confidence: 0.9, estimatedCalories: 72, reason: "unit test")],
            date: breakfast,
            source: "unit-test"
        )
        _ = try store.recordMealCalories(
            from: [FoodPrediction(foodName: "Milk", inventoryItemId: nil, confidence: 0.8, estimatedCalories: 149, reason: "unit test")],
            date: dinner,
            source: "unit-test"
        )
        _ = try store.recordMealCalories(
            from: [FoodPrediction(foodName: "Rice", inventoryItemId: nil, confidence: 0.8, estimatedCalories: 170, reason: "unit test")],
            date: nextDay,
            source: "unit-test"
        )

        XCTAssertEqual(firstRecord.totalCalories, 72)
        XCTAssertEqual(store.dailyCalories(on: breakfast, calendar: calendar), 221)

        let reloaded = LocalFoodStore(fileURL: url, seedIfEmpty: false)
        XCTAssertEqual(reloaded.mealRecords.count, 3)
        XCTAssertEqual(reloaded.dailyCalories(on: breakfast, calendar: calendar), 221)
        try? FileManager.default.removeItem(at: url)
    }

    func testStoreLoadsLegacySnapshotWithoutMealRecords() throws {
        let url = tempURL()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let item = LocalFoodKnowledge.makeFoodItem(name: "eggs", source: "unit-test")
        let data = try encoder.encode(PantryStoreSnapshot(items: [item], events: []))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "mealRecords")
        let legacyData = try JSONSerialization.data(withJSONObject: json)
        try legacyData.write(to: url)

        let store = LocalFoodStore(fileURL: url, seedIfEmpty: false)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertTrue(store.mealRecords.isEmpty)
        try? FileManager.default.removeItem(at: url)
    }
}
