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
}
