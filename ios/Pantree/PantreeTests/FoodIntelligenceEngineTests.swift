import XCTest
@testable import Pantree

final class FoodIntelligenceEngineTests: XCTestCase {
    func testSummaryBuildsRiskHealthShoppingAndMeals() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = ISO8601DateFormatter().date(from: "2026-01-15T12:00:00Z")!
        let items = SampleData.initialInventory(now: now, calendar: calendar)
        let summary = FoodIntelligenceEngine(calendar: calendar).buildSummary(items: items, events: [], on: now)

        XCTAssertEqual(summary.activeCount, 5)
        XCTAssertGreaterThan(summary.healthBalance.score, 70)
        XCTAssertTrue(summary.expiryRisks.contains { $0.item.canonicalName == "spinach" })
        XCTAssertGreaterThan(summary.valueAtRisk, 0)
        XCTAssertTrue(summary.shoppingSuggestions.contains { $0.name == "Protein option" })
        XCTAssertTrue(summary.mealIdeas.contains { $0.name == "Spinach Egg Scramble" })
        XCTAssertTrue(summary.mlReadiness.contains { $0.contains("Core ML") })
    }

    func testShoppingSuggestionsUseRecentConsumption() {
        let now = ISO8601DateFormatter().date(from: "2026-01-15T12:00:00Z")!
        let rice = LocalFoodKnowledge.makeFoodItem(name: "rice", buyDate: now, source: "unit-test")
        let event = FoodEvent(type: .consume, foodName: "Eggs", source: "unit-test", createdAt: now)
        let suggestions = FoodIntelligenceEngine().buildShoppingSuggestions(items: [rice], events: [event], on: now)

        XCTAssertTrue(suggestions.contains { $0.name == "Eggs" })
        XCTAssertTrue(suggestions.contains { $0.name == "Leafy greens" })
    }
}
