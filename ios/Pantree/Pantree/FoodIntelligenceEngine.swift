import Foundation

struct PantrySummary: Equatable {
    var activeCount: Int
    var totalCount: Int
    var categoryCounts: [FoodCategory: Int]
    var sectionCounts: [StorageSection: Int]
    var totalEstimatedValue: Double
    var valueAtRisk: Double
    var expiryRisks: [ExpiryRisk]
    var healthBalance: HealthBalance
    var shoppingSuggestions: [ShoppingSuggestion]
    var mealIdeas: [MealIdea]
    var mlReadiness: [String]
}

struct FoodIntelligenceEngine: Sendable {
    var calendar: Calendar = .current

    func buildSummary(items: [FoodItem], events: [FoodEvent] = [], on date: Date = Date()) -> PantrySummary {
        let activeItems = items.filter(\.isActive)
        let categoryCounts = Dictionary(grouping: activeItems, by: \.category).mapValues(\.count)
        let sectionCounts = Dictionary(grouping: activeItems, by: \.section).mapValues(\.count)
        let totalValue = activeItems.compactMap { $0.estimatedRemainingValue() }.reduce(0, +).rounded(toPlaces: 2)
        let expiryRisks = buildExpiryRisks(items: activeItems, on: date)
        let valueAtRisk = expiryRisks.compactMap(\.valueAtRisk).reduce(0, +).rounded(toPlaces: 2)

        return PantrySummary(
            activeCount: activeItems.count,
            totalCount: items.count,
            categoryCounts: categoryCounts,
            sectionCounts: sectionCounts,
            totalEstimatedValue: totalValue,
            valueAtRisk: valueAtRisk,
            expiryRisks: expiryRisks,
            healthBalance: buildHealthBalance(items: activeItems),
            shoppingSuggestions: buildShoppingSuggestions(items: activeItems, events: events, on: date),
            mealIdeas: buildMealIdeas(items: activeItems, risks: expiryRisks),
            mlReadiness: [
                "On-device receipt text extraction can run Vision OCR on captured images without uploading photos.",
                "Food photo recognition can use a small Core ML classifier with local confirmation.",
                "Quantity estimation should combine repeated camera views, inventory state, and user corrections.",
                "Restock timing can be learned from local event history only."
            ]
        )
    }

    func buildExpiryRisks(items: [FoodItem], on date: Date = Date()) -> [ExpiryRisk] {
        items.compactMap { item in
            let daysLeft = item.daysUntilExpiration(on: date, calendar: calendar)
            guard daysLeft <= 5 else { return nil }
            let urgency = max(0, 5 - daysLeft) * 12
            let quantityPressure = Int((1 - item.remainingShare()) * -10)
            let valuePressure = item.price == nil ? 0 : 8
            let score = min(100, max(0, 45 + urgency + valuePressure + quantityPressure))
            let reason: String
            if daysLeft < 0 {
                reason = "Past predicted expiration; verify before eating."
            } else if daysLeft == 0 {
                reason = "Predicted to expire today."
            } else {
                reason = "Predicted to expire in \(daysLeft) day\(daysLeft == 1 ? "" : "s")."
            }
            return ExpiryRisk(
                id: item.id,
                item: item,
                score: score,
                reason: reason,
                daysLeft: daysLeft,
                valueAtRisk: item.estimatedRemainingValue()
            )
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score { return lhs.daysLeft < rhs.daysLeft }
            return lhs.score > rhs.score
        }
    }

    func buildHealthBalance(items: [FoodItem]) -> HealthBalance {
        guard !items.isEmpty else {
            return HealthBalance(score: 0, produceShare: 0, proteinShare: 0, treatShare: 0, insights: ["Add a few foods to start local nutrition insights."])
        }

        let total = Double(items.count)
        let produceShare = Double(items.filter { $0.category == .produce }.count) / total
        let proteinShare = Double(items.filter { $0.category == .protein }.count) / total
        let treatShare = Double(items.filter { $0.category == .treat }.count) / total
        var score = 55
        var insights: [String] = []

        if produceShare >= 0.3 {
            score += 18
            insights.append("Good produce coverage for fresh meals.")
        } else {
            insights.append("Add more produce for fiber and micronutrients.")
        }

        if proteinShare >= 0.2 {
            score += 15
            insights.append("Protein options are available for balanced meals.")
        } else {
            insights.append("Protein coverage is low; consider eggs, beans, tofu, fish, or chicken.")
        }

        if treatShare > 0.25 {
            score -= 18
            insights.append("Treats are a high share of current inventory.")
        }

        return HealthBalance(
            score: min(100, max(0, score)),
            produceShare: produceShare.rounded(toPlaces: 2),
            proteinShare: proteinShare.rounded(toPlaces: 2),
            treatShare: treatShare.rounded(toPlaces: 2),
            insights: insights
        )
    }

    func buildShoppingSuggestions(items: [FoodItem], events: [FoodEvent], on date: Date = Date()) -> [ShoppingSuggestion] {
        var suggestions: [ShoppingSuggestion] = []
        let activeNames = Set(items.map { $0.canonicalName })
        let categoryCounts = Dictionary(grouping: items, by: \.category).mapValues(\.count)

        if categoryCounts[.produce, default: 0] < 2 {
            suggestions.append(ShoppingSuggestion(name: "Leafy greens", reason: "Produce variety is low.", priority: "high"))
        }
        if categoryCounts[.protein, default: 0] < 2 {
            suggestions.append(ShoppingSuggestion(name: "Protein option", reason: "Add eggs, beans, tofu, chicken, or fish.", priority: "medium"))
        }
        if !activeNames.contains("eggs") {
            suggestions.append(ShoppingSuggestion(name: "Eggs", reason: "Versatile protein for breakfast and quick meals.", priority: "medium"))
        }
        if !activeNames.contains("milk") && !activeNames.contains("yogurt") {
            suggestions.append(ShoppingSuggestion(name: "Dairy or yogurt", reason: "Breakfast and snack basics are missing.", priority: "low"))
        }

        let recentConsumed = events.filter { event in
            guard event.type == .consume else { return false }
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: event.createdAt), to: calendar.startOfDay(for: date)).day ?? 999
            return days <= 7 && !activeNames.contains(LocalFoodKnowledge.profile(for: event.foodName).canonicalName)
        }
        for event in recentConsumed.prefix(3) {
            suggestions.append(ShoppingSuggestion(name: event.foodName, reason: "Recently consumed locally; consider restocking if it is a staple.", priority: "medium"))
        }

        return Array(suggestions.prefix(6))
    }

    func buildMealIdeas(items: [FoodItem], risks: [ExpiryRisk]) -> [MealIdea] {
        let activeNames = Set(items.map { $0.canonicalName })
        let expiringNames = Set(risks.map { $0.item.canonicalName })

        return LocalFoodKnowledge.recipes.compactMap { recipe in
            let matched = recipe.ingredients.filter { activeNames.contains($0) }
            guard !matched.isEmpty else { return nil }
            let missing = recipe.ingredients.filter { !activeNames.contains($0) }
            let expiringMatches = recipe.ingredients.filter { expiringNames.contains($0) }
            let matchScore = Int((Double(matched.count) / Double(recipe.ingredients.count)) * 100) + expiringMatches.count * 10
            return MealIdea(
                id: recipe.id,
                name: recipe.name,
                ingredients: recipe.ingredients,
                matched: matched,
                missing: missing,
                expiringMatches: expiringMatches,
                minutes: recipe.minutes,
                healthGoal: recipe.healthGoal,
                matchScore: min(100, matchScore)
            )
        }
        .sorted { $0.matchScore > $1.matchScore }
    }
}
