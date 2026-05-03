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

    func testWholeFoodsOCRSkipsStoreAddressAdminAndNonFoodLines() {
        let receipt = """
        WHOLE
        FOODS.
        MARKET
        Bryant Park BPK
        1095 6th Ave
        New York, NY 10036
        917-728-5700
        365 WHL MLK
        OVF OG LG EGGS
        365 OG ROMAINE BAG
        BROO BROWN ALE
        BOTTLE DEPOSIT
        NOOSA HONEY YOGHURT
        DRSCL STRAWBERRIES
        365 SALTED CORN CHIPS
        PNLND GRND BEEF 85/15 1LB
        365 MBO PAPER TOWELS
        365 CHUNKY SALSA
        365 PNBTR BALLS OG
        PDVG WHITE BAGTT
        LACRX GRAPEFRUIT 12PK
        BOTTLE DEPOSIT
        Subtotal:
        4.09
        F
        2.89
        F
        3.79
        F
        12.99
        T
        0.05
        T
        2.49
        F
        4.99
        F
        3.49
        F
        8.99
        F
        6.99
        T
        3.29
        F
        4.99
        F
        2.99
        F
        5.49
        F
        0.05
        T
        Net Sales:
        66.48
        Tax:
        0.81
        8.88%
        Total:
        67.29
        Sold Items:
        15
        Paid:
        VISA:
        $67.29
        MID: 123456
        TID: 789012
        """

        let result = ReceiptParser().parse(receipt)
        let canonicalNames = result.items.map(\.canonicalName)
        let displayNames = result.items.map { $0.name.lowercased() }

        XCTAssertEqual(canonicalNames, [
            "milk",
            "eggs",
            "lettuce",
            "yogurt",
            "strawberries",
            "chips",
            "beef",
            "salsa",
            "peanut butter",
            "bread",
            "grapefruit"
        ])
        XCTAssertEqual(result.items.first { $0.canonicalName == "milk" }?.price, 4.09)
        XCTAssertEqual(result.items.first { $0.canonicalName == "beef" }?.price, 8.99)
        XCTAssertEqual(result.items.first { $0.canonicalName == "grapefruit" }?.price, 5.49)

        XCTAssertFalse(displayNames.contains("whole"))
        XCTAssertFalse(displayNames.contains("foods"))
        XCTAssertFalse(displayNames.contains("market"))
        XCTAssertFalse(displayNames.contains { $0.contains("bryant park") })
        XCTAssertFalse(displayNames.contains { $0.contains("6th ave") })
        XCTAssertFalse(displayNames.contains { $0.contains("paper towels") })
        XCTAssertFalse(displayNames.contains { $0.contains("bottle deposit") })
        XCTAssertFalse(displayNames.contains { $0.contains("brown ale") })
    }

    func testReceiptDateAndTimeBecomeInFridgeDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let fallback = ISO8601DateFormatter().date(from: "2026-01-10T09:30:00Z")!
        let result = ReceiptParser(calendar: calendar).parse("""
        PANTREE MARKET
        Date: 05/01/2026
        Time: 4:45 PM
        WHOLE MILK $3.99
        TOTAL 3.99
        """, purchaseDate: fallback)

        let expectedBuyDate = makeDate(calendar: calendar, year: 2026, month: 5, day: 1, hour: 16, minute: 45)
        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.items[0].buyDate, expectedBuyDate)
        XCTAssertEqual(result.items[0].expDate, calendar.date(byAdding: .day, value: 7, to: expectedBuyDate))
    }

    func testMissingReceiptDateUsesFallbackInFridgeDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let fallback = ISO8601DateFormatter().date(from: "2026-01-10T09:30:00Z")!
        let result = ReceiptParser(calendar: calendar).parse("""
        WHOLE MILK $3.99
        TOTAL 3.99
        """, purchaseDate: fallback)

        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.items[0].buyDate, fallback)
    }

    func testStandaloneWholeDoesNotBecomeSeparateMilkItem() {
        let result = ReceiptParser().parse("""
        WHOLE
        WHOLE MILK $3.99
        TOTAL 3.99
        """)

        XCTAssertEqual(result.items.map(\.name), ["Whole Milk"])
        XCTAssertEqual(result.items.map(\.canonicalName), ["milk"])
    }

    func testReceiptPhotoOCRTextNormalization() {
        let text = ReceiptImageTextRecognizer.normalizedOCRText("""

             EGGS 4.99

          MILK $3.99   
        
        """)

        XCTAssertEqual(text, "EGGS 4.99\nMILK $3.99")
    }

    private func makeDate(calendar: Calendar, year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        components.nanosecond = 0
        return calendar.date(from: components)!
    }
}
