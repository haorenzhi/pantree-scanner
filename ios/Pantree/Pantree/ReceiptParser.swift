import Foundation

struct ReceiptParseResult: Equatable {
    var receiptId: String
    var items: [FoodItem]
    var ignoredLines: [String]
}

struct ReceiptParser: Sendable {
    var calendar: Calendar = .current

    func parse(_ text: String, purchaseDate: Date = Date()) -> ReceiptParseResult {
        let receiptId = UUID().uuidString
        var parsedItems: [FoodItem] = []
        var ignoredLines: [String] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            guard shouldParseLine(trimmed), let candidate = extractCandidate(from: trimmed) else {
                ignoredLines.append(trimmed)
                continue
            }

            var item = LocalFoodKnowledge.makeFoodItem(
                name: candidate.name,
                buyDate: purchaseDate,
                price: candidate.price,
                quantity: candidate.quantity,
                source: "receipt",
                calendar: calendar
            )
            item.receiptId = receiptId
            parsedItems.append(item)
        }

        return ReceiptParseResult(receiptId: receiptId, items: parsedItems, ignoredLines: ignoredLines)
    }

    private func shouldParseLine(_ line: String) -> Bool {
        let normalized = LocalFoodKnowledge.normalize(line)
        guard normalized.count >= 3 else { return false }
        if normalized.range(of: #"^\d+[/-]\d+[/-]\d+"#, options: .regularExpression) != nil { return false }
        let blockedWords = [
            "subtotal", "total", "tax", "balance", "cash", "change", "visa", "mastercard", "amex",
            "debit", "credit", "approval", "thank", "receipt", "store", "cashier", "phone", "member", "savings", "market"
        ]
        return !blockedWords.contains { normalized.contains($0) }
    }

    private func extractCandidate(from line: String) -> (name: String, quantity: Double, price: Double?)? {
        var working = line.replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let price = extractTrailingPrice(from: &working)
        let quantity = extractLeadingQuantity(from: &working) ?? 1

        working = working
            .replacingOccurrences(of: #"^[A-Z0-9]{3,}\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\b(ORG|ORGANIC|FRESH|REG|EA|LB|PKG)\b"#, with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"[^A-Za-z\s-]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard working.count >= 3, working.rangeOfCharacter(from: .letters) != nil else { return nil }
        return (name: working, quantity: max(0.01, quantity), price: price)
    }

    private func extractTrailingPrice(from line: inout String) -> Double? {
        let pattern = #"(?:\$\s*)?(\d+\.\d{2})\s*$"#
        guard let range = line.range(of: pattern, options: .regularExpression) else { return nil }
        let priceText = String(line[range])
            .replacingOccurrences(of: "$", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        line.removeSubrange(range)
        line = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(priceText)
    }

    private func extractLeadingQuantity(from line: inout String) -> Double? {
        let pattern = #"^(\d+(?:\.\d+)?)\s*(?:x|X|@)?\s+"#
        guard let range = line.range(of: pattern, options: .regularExpression) else { return nil }
        let quantityText = String(line[range])
            .replacingOccurrences(of: "x", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "@", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        line.removeSubrange(range)
        line = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(quantityText)
    }
}
