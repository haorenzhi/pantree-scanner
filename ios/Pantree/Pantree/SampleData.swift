import Foundation

enum SampleData {
    static let referenceDate = ISO8601DateFormatter().date(from: "2026-01-15T12:00:00Z") ?? Date()

    static func initialInventory(now: Date = Date(), calendar: Calendar = .current) -> [FoodItem] {
        var spinach = LocalFoodKnowledge.makeFoodItem(name: "spinach", buyDate: calendar.date(byAdding: .day, value: -3, to: now) ?? now, price: 3.49, quantity: 1, source: "sample", calendar: calendar)
        spinach.expDate = calendar.date(byAdding: .day, value: 1, to: now) ?? now

        var eggs = LocalFoodKnowledge.makeFoodItem(name: "eggs", buyDate: calendar.date(byAdding: .day, value: -7, to: now) ?? now, price: 4.99, quantity: 12, source: "sample", calendar: calendar)
        eggs.remainingQty = 6

        var milk = LocalFoodKnowledge.makeFoodItem(name: "milk", buyDate: calendar.date(byAdding: .day, value: -4, to: now) ?? now, price: 3.99, quantity: 1, source: "sample", calendar: calendar)
        milk.expDate = calendar.date(byAdding: .day, value: 3, to: now) ?? now

        let rice = LocalFoodKnowledge.makeFoodItem(name: "rice", buyDate: calendar.date(byAdding: .day, value: -20, to: now) ?? now, price: 6.49, quantity: 1, source: "sample", calendar: calendar)
        let apples = LocalFoodKnowledge.makeFoodItem(name: "apples", buyDate: calendar.date(byAdding: .day, value: -2, to: now) ?? now, price: 5.25, quantity: 6, source: "sample", calendar: calendar)

        return [spinach, eggs, milk, rice, apples]
    }

    static let sampleReceipt = """
    PANTREE MARKET
    2 EGGS 4.99
    BABY SPINACH 3.49
    WHOLE MILK $3.99
    BANANAS 1.29
    TAX 0.20
    TOTAL 13.96
    THANK YOU
    """
}
