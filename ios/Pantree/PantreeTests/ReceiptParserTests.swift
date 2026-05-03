import XCTest
@testable import Pantree

final class ReceiptParserTests: XCTestCase {
    func testParsesReceiptItemsAndIgnoresTotals() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = ISO8601DateFormatter().date(from: "2026-01-10T12:00:00Z")!
        let result = ReceiptParser(calendar: calendar).parse(SampleData.sampleReceipt, purchaseDate: date)

        XCTAssertEqual(result.items.map(\.canonicalName), ["eggs", "spinach", "milk", "bananas"])
        XCTAssertTrue(result.ignoredLines.contains { $0.contains("TOTAL") })
        XCTAssertEqual(result.items.first?.quantity, 2)
        XCTAssertEqual(result.items.first?.price, 4.99)
        XCTAssertEqual(result.items[1].source, "receipt")
        XCTAssertNotNil(result.items[1].receiptId)
    }

    func testParsesUnknownFoodWithoutExternalLookup() {
        let result = ReceiptParser().parse("ZORPLE NUGGET 2.99")
        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.items[0].category, .unknown)
        XCTAssertEqual(result.items[0].confidence, 0.45, accuracy: 0.001)
    }

    func testEmptyOrAdminOnlyReceiptReturnsNoItems() {
        let result = ReceiptParser().parse("""
        STORE RECEIPT
        TAX 0.20
        TOTAL 3.99
        THANK YOU
        """)
        XCTAssertTrue(result.items.isEmpty)
        XCTAssertEqual(result.ignoredLines.count, 4)
    }
}
