import XCTest
@testable import Pantree

final class FoodKnowledgeTests: XCTestCase {
    func testProfileLookupUsesAliases() {
        let spinach = LocalFoodKnowledge.profile(for: "Baby Spinach")
        XCTAssertEqual(spinach.canonicalName, "spinach")
        XCTAssertEqual(spinach.category, .produce)
        XCTAssertEqual(spinach.section, .fridge)
    }

    func testUnknownProfileStaysLocalAndLowConfidence() {
        let item = LocalFoodKnowledge.makeFoodItem(name: "dragon fruit crisps", source: "unit-test")
        XCTAssertEqual(item.category, .unknown)
        XCTAssertEqual(item.confidence, 0.45, accuracy: 0.001)
        XCTAssertEqual(item.source, "unit-test")
    }

    func testGenericModifiersDoNotReverseMatchFoodAliases() {
        let profile = LocalFoodKnowledge.profile(for: "Whole")
        XCTAssertEqual(profile.category, .unknown)
        XCTAssertEqual(profile.canonicalName, "whole")
    }

    func testFoodIconsUseLocalBridgeEmojiLogic() {
        XCTAssertEqual(LocalFoodKnowledge.icon(for: "Whole Milk"), "🥛")
        XCTAssertEqual(LocalFoodKnowledge.icon(for: "OVF OG LG EGGS"), "🥚")
        XCTAssertEqual(LocalFoodKnowledge.icon(for: "Chunky Salsa"), "🫙")
        XCTAssertEqual(LocalFoodKnowledge.icon(for: "Salted Corn Chips"), "🌽")
    }

    func testFoodItemIconUsesCanonicalThenDisplayNameThenDefault() {
        var item = LocalFoodKnowledge.makeFoodItem(name: "Salted Corn Chips", source: "unit-test")
        item.canonicalName = "chips"
        XCTAssertEqual(item.icon, "🌽")

        XCTAssertEqual(LocalFoodKnowledge.icon(for: "Whole"), "🍽️")
        XCTAssertEqual(LocalFoodKnowledge.icon(for: "dragon fruit crisps"), "🍽️")
    }

    func testFoodItemComputesExpirationAndRemainingValue() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let buyDate = ISO8601DateFormatter().date(from: "2026-01-01T12:00:00Z")!
        let item = LocalFoodKnowledge.makeFoodItem(name: "milk", buyDate: buyDate, price: 4, quantity: 2, source: "unit-test", calendar: calendar)
        XCTAssertEqual(item.daysUntilExpiration(on: buyDate, calendar: calendar), 7)
        XCTAssertEqual(item.estimatedRemainingValue(), 4)
    }
}
