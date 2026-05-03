import Foundation

struct ReceiptParseResult: Equatable {
    var receiptId: String
    var items: [FoodItem]
    var ignoredLines: [String]
}

private struct ReceiptCandidate: Equatable {
    var rawLine: String
    var name: String
    var quantity: Double
    var price: Double?
    var taxCode: String?
}

private struct SplitPriceToken: Equatable {
    var price: Double
    var taxCode: String?
    var nextIndex: Int
}

struct ReceiptParser: Sendable {
    var calendar: Calendar = .current

    private static let abbreviations: [String: String] = [
        "ORG": "Organic",
        "OG": "Organic",
        "GRN": "Green",
        "GRD": "Ground",
        "GRND": "Ground",
        "BF": "Beef",
        "VEG": "Vegetable",
        "FRZ": "Frozen",
        "FRSH": "Fresh",
        "WHL": "Whole",
        "MLK": "Milk",
        "WHLMLK": "Whole Milk",
        "LG": "Large",
        "SM": "Small",
        "MED": "Medium",
        "WHT": "White",
        "YLW": "Yellow",
        "RED": "Red",
        "BLK": "Black",
        "PNBTR": "Peanut Butter",
        "SLTD": "Salted",
        "YOGHURT": "Yogurt",
        "YGHRT": "Yogurt",
        "BAGTT": "Baguette",
        "LB": "",
        "OZ": "",
        "CT": "",
        "EA": "",
        "PK": "",
        "0G": ""
    ]

    private static let foodKeywords = [
        "milk", "eggs", "egg", "yogurt", "yoghurt", "cheese", "butter",
        "strawberries", "strawberry", "blueberries", "blueberry", "grapefruit",
        "romaine", "lettuce", "spinach", "broccoli", "corn", "salsa",
        "chips", "beef", "pork", "chicken", "salmon", "shrimp", "tofu",
        "bread", "baguette", "bagel", "rice", "beans", "pasta", "cereal",
        "peanut", "apple", "banana", "orange", "tomato", "carrot", "juice"
    ]

    func parse(_ text: String, purchaseDate: Date = Date()) -> ReceiptParseResult {
        let receiptId = UUID().uuidString
        var parsedItems: [FoodItem] = []
        var ignoredLines: [String] = []
        var pendingCandidates: [ReceiptCandidate] = []

        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let inFridgeDate = receiptInFridgeDate(from: lines, fallback: purchaseDate)
        var index = 0

        while index < lines.count {
            let trimmed = lines[index]
            guard !trimmed.isEmpty else {
                index += 1
                continue
            }

            if let splitPrice = splitPriceToken(at: index, in: lines), !pendingCandidates.isEmpty {
                var candidate = pendingCandidates.removeFirst()
                candidate.price = splitPrice.price
                candidate.taxCode = splitPrice.taxCode
                append(candidate, receiptId: receiptId, purchaseDate: inFridgeDate, to: &parsedItems, ignoredLines: &ignoredLines)
                index = splitPrice.nextIndex
                continue
            }

            if isStandalonePriceLine(trimmed) {
                ignoredLines.append(trimmed)
                index += 1
                continue
            }

            if isAdministrativeLine(trimmed) {
                ignoredLines.append(trimmed)
                index += 1
                continue
            }

            if let candidate = extractCandidate(from: trimmed, requiringPrice: true) {
                append(candidate, receiptId: receiptId, purchaseDate: inFridgeDate, to: &parsedItems, ignoredLines: &ignoredLines, allowUnknownWhenPriced: true)
            } else if let pendingCandidate = extractCandidate(from: trimmed, requiringPrice: false), shouldQueueForSplitPrice(pendingCandidate) {
                pendingCandidates.append(pendingCandidate)
            } else {
                ignoredLines.append(trimmed)
            }

            index += 1
        }

        ignoredLines.append(contentsOf: pendingCandidates.map(\.rawLine))

        return ReceiptParseResult(receiptId: receiptId, items: parsedItems, ignoredLines: ignoredLines)
    }

    private func receiptInFridgeDate(from lines: [String], fallback: Date) -> Date {
        var dateComponents: DateComponents?
        var timeComponents: DateComponents?

        for line in lines where !line.isEmpty {
            if dateComponents == nil {
                dateComponents = extractReceiptDate(from: line)
            }
            if timeComponents == nil {
                timeComponents = extractReceiptTime(from: line)
            }
            if dateComponents != nil, timeComponents != nil { break }
        }

        guard var components = dateComponents else { return fallback }
        let fallbackTime = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: fallback)

        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.hour = timeComponents?.hour ?? fallbackTime.hour
        components.minute = timeComponents?.minute ?? fallbackTime.minute
        components.second = timeComponents?.second ?? fallbackTime.second
        components.nanosecond = timeComponents?.nanosecond ?? fallbackTime.nanosecond

        return calendar.date(from: components) ?? fallback
    }

    private func extractReceiptDate(from line: String) -> DateComponents? {
        if let groups = regexGroups(#"\b(\d{4})[/\-](\d{1,2})[/\-](\d{1,2})\b"#, in: line),
           let year = Int(groups[0]),
           let month = Int(groups[1]),
           let day = Int(groups[2]),
           isValid(month: month, day: day) {
            return DateComponents(year: year, month: month, day: day)
        }

        if let groups = regexGroups(#"\b(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})\b"#, in: line),
           let month = Int(groups[0]),
           let day = Int(groups[1]),
           let rawYear = Int(groups[2]),
           isValid(month: month, day: day) {
            return DateComponents(year: normalizedYear(rawYear), month: month, day: day)
        }

        return nil
    }

    private func extractReceiptTime(from line: String) -> DateComponents? {
        guard let groups = regexGroups(#"\b(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([AP]M)?\b"#, in: line),
              var hour = Int(groups[0]),
              let minute = Int(groups[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else { return nil }

        let second = Int(groups[2]) ?? 0
        guard (0...59).contains(second) else { return nil }

        let meridiem = groups[3].uppercased()
        if meridiem == "PM", hour < 12 {
            hour += 12
        } else if meridiem == "AM", hour == 12 {
            hour = 0
        }

        return DateComponents(hour: hour, minute: minute, second: second, nanosecond: 0)
    }

    private func regexGroups(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)) else {
            return nil
        }

        return (1..<match.numberOfRanges).map { index in
            guard match.range(at: index).location != NSNotFound,
                  let range = Range(match.range(at: index), in: text) else { return "" }
            return String(text[range])
        }
    }

    private func normalizedYear(_ year: Int) -> Int {
        if year < 100 {
            return year >= 70 ? 1900 + year : 2000 + year
        }
        return year
    }

    private func isValid(month: Int, day: Int) -> Bool {
        (1...12).contains(month) && (1...31).contains(day)
    }

    private func append(
        _ candidate: ReceiptCandidate,
        receiptId: String,
        purchaseDate: Date,
        to parsedItems: inout [FoodItem],
        ignoredLines: inout [String],
        allowUnknownWhenPriced: Bool = false
    ) {
        guard let price = candidate.price, shouldImport(candidate, allowUnknownWhenPriced: allowUnknownWhenPriced) else {
            ignoredLines.append(candidate.rawLine)
            return
        }

        var item = LocalFoodKnowledge.makeFoodItem(
            name: candidate.name,
            buyDate: purchaseDate,
            price: price,
            quantity: candidate.quantity,
            source: "receipt",
            calendar: calendar
        )
        item.receiptId = receiptId
        parsedItems.append(item)
    }

    private func isAdministrativeLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return true }

        let patterns = [
            #"\b(TOTAL|SUBTOTAL|SUB\s*TOTAL)\b"#,
            #"\b(TAX|SALES\s*TAX|HST|GST|PST)\b"#,
            #"\b(CHANGE|CASH|CREDIT|DEBIT|TENDER|PAYMENT|PAID|BALANCE)\b"#,
            #"\b(VISA|MASTERCARD|AMEX|DISCOVER|INTERAC)\b"#,
            #"\b(THANK\s*YOU|WELCOME|COME\s*AGAIN|HAVE\s*A)\b"#,
            #"\b(STORE|RECEIPT|TRANSACTION|CASHIER|REGISTER)\b"#,
            #"\b(MEMBER|LOYALTY|REWARDS|SAVINGS|DISCOUNT|COUPON)\b"#,
            #"\b(REFUND|RETURN|VOID|CANCEL)\b"#,
            #"\b(TEL|FAX|PHONE|WWW\.|HTTP|\.COM|\.CA)\b"#,
            #"\b(NET\s*SALES|SOLD\s*ITEMS|SOLD\s*ITEM)\b"#,
            #"\b(MID|TID|TERMINAL|AUTH|APPROVAL|SEQUENCE)\b"#,
            #"\b(MARKET|FOODS|GROCERY|SUPERMRKT|SUPERMARKET)\b"#,
            #"^F?CODS\.?$"#,
            #"BRYANT\s*PARK|BPK$"#,
            #"^[A-Z]{2,}PARK"#,
            #"\d{3}[\-.]\d{3}[\-.]\d{4}"#,
            #"\b[A-Z]{2}\s*\d{5}\b"#,
            #"\b\d+\w*\s*(Ave|St|Rd|Blvd|Dr|Ln|Way|Pkwy|Ct)\b"#,
            #"^\d{6,}$"#,
            #"^\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4}"#,
            #"^\d{1,2}:\d{2}"#,
            #"^[#*]"#,
            #"^[\-=_]{3,}$"#,
            #"^\s*\*{3,}"#,
            #"^\d+$"#,
            #"NETSALES"#,
            #"SOLDITEMS"#
        ]

        return patterns.contains { trimmed.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil }
    }

    private func extractCandidate(from line: String, requiringPrice: Bool) -> ReceiptCandidate? {
        var working = line.replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let price = extractTrailingPrice(from: &working)
        guard !requiringPrice || price != nil else { return nil }

        let quantity = extractLeadingQuantity(from: &working) ?? 1
        let name = normalizeItemName(working)

        guard name.count >= 3, name.rangeOfCharacter(from: .letters) != nil else { return nil }
        return ReceiptCandidate(rawLine: line, name: name, quantity: max(0.01, quantity), price: price?.value, taxCode: price?.taxCode)
    }

    private func normalizeItemName(_ rawName: String) -> String {
        var name = rawName
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        name = name.replacingOccurrences(of: #"^\s*\d+\s*[x@]\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
        name = name.replacingOccurrences(of: #"\b\d+/\d+\b"#, with: " ", options: .regularExpression)
        name = name.replacingOccurrences(of: #"\b\d+\s*(?:PK|CT|OZ|LB|EA|KG|G)\b"#, with: " ", options: [.regularExpression, .caseInsensitive])

        let brandPattern = #"^(365|KIRKLAND|GV|MMRK|STORE|HEB|TJ|PVLB|PDVG|PNLND|LACRX|BROO|DRSCL|NOOSA|OVFOGL|OVF|MBO)\s*"#
        var previous: String
        repeat {
            previous = name
            name = name.replacingOccurrences(of: brandPattern, with: "", options: [.regularExpression, .caseInsensitive])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } while name != previous

        name = name.replacingOccurrences(of: #"[^A-Za-z\s-]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let expandedWords = name.split(separator: " ").flatMap { word -> [String] in
            let key = word.uppercased().trimmingCharacters(in: .punctuationCharacters)
            guard let replacement = Self.abbreviations[key] else { return [String(word)] }
            return replacement.split(separator: " ").map(String.init)
        }

        name = expandedWords.joined(separator: " ")
            .replacingOccurrences(of: #"\b(ORGANIC|FRESH|LARGE|SMALL|MEDIUM|PACKAGE|PKG|BAG|REG|EA|LB|OZ|CT|PK)\b"#, with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return name
    }

    private func extractTrailingPrice(from line: inout String) -> (value: Double, taxCode: String?)? {
        let pattern = #"(?:\$\s*)?(\d+\.\d{2})\s*([FfTt]?)\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)),
              let fullRange = Range(match.range(at: 0), in: line),
              let priceRange = Range(match.range(at: 1), in: line) else { return nil }

        let priceText = String(line[priceRange])
        let taxCode: String?
        if match.range(at: 2).location != NSNotFound, let taxRange = Range(match.range(at: 2), in: line) {
            let rawTaxCode = String(line[taxRange]).uppercased()
            taxCode = rawTaxCode.isEmpty ? nil : rawTaxCode
        } else {
            taxCode = nil
        }

        line.removeSubrange(fullRange)
        line = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(priceText) else { return nil }
        return (value, taxCode)
    }

    private func extractLeadingQuantity(from line: inout String) -> Double? {
        if line.range(of: #"^365\s+"#, options: [.regularExpression, .caseInsensitive]) != nil { return nil }

        let pattern = #"^(?:(\d+(?:\.\d+)?)\s*[x@]\s+|([1-9]|1\d|2\d)\s+)"#
        guard let range = line.range(of: pattern, options: .regularExpression) else { return nil }
        let quantityText = String(line[range])
            .replacingOccurrences(of: "x", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "@", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        line.removeSubrange(range)
        line = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(quantityText)
    }

    private func splitPriceToken(at index: Int, in lines: [String]) -> SplitPriceToken? {
        let line = lines[index]
        if let token = priceOnlyWithInlineTaxCode(line, nextIndex: index + 1) {
            return token
        }

        guard let price = standalonePrice(line), let taxIndex = nextNonEmptyIndex(after: index, in: lines) else {
            return nil
        }

        let taxCode = lines[taxIndex].trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard taxCode == "F" || taxCode == "T" else { return nil }
        return SplitPriceToken(price: price, taxCode: taxCode, nextIndex: taxIndex + 1)
    }

    private func priceOnlyWithInlineTaxCode(_ line: String, nextIndex: Int) -> SplitPriceToken? {
        let pattern = #"^\$?\s*(\d+\.\d{2})\s*([FfTt])$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)),
              let priceRange = Range(match.range(at: 1), in: line),
              let taxRange = Range(match.range(at: 2), in: line),
              let price = Double(String(line[priceRange])) else { return nil }

        return SplitPriceToken(price: price, taxCode: String(line[taxRange]).uppercased(), nextIndex: nextIndex)
    }

    private func standalonePrice(_ line: String) -> Double? {
        let pattern = #"^\$?\s*(\d+\.\d{2})$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)),
              let priceRange = Range(match.range(at: 1), in: line) else { return nil }
        return Double(String(line[priceRange]))
    }

    private func nextNonEmptyIndex(after index: Int, in lines: [String]) -> Int? {
        var next = index + 1
        while next < lines.count {
            if !lines[next].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return next
            }
            next += 1
        }
        return nil
    }

    private func isStandalonePriceLine(_ line: String) -> Bool {
        line.range(of: #"^\$?\s*\d+\.\d{2}\s*[FfTt]?$"#, options: .regularExpression) != nil
            || line.range(of: #"^\d+(?:\.\d+)?%$"#, options: .regularExpression) != nil
    }

    private func shouldQueueForSplitPrice(_ candidate: ReceiptCandidate) -> Bool {
        let normalized = LocalFoodKnowledge.normalize(candidate.name)
        guard normalized.count >= 3, !isModifierOnlyName(candidate.name) else { return false }
        let alphaCount = normalized.filter(\.isLetter).count
        let alphaRatio = Double(alphaCount) / Double(max(normalized.count, 1))

        return alphaRatio >= 0.45
            && (containsFoodKeyword(candidate.name)
                || isNonFoodProduct(candidate)
                || LocalFoodKnowledge.profile(for: candidate.name).category != .unknown
                || candidate.rawLine.range(of: #"^(365|KIRKLAND|GV|MMRK|STORE|HEB|TJ|PVLB|PDVG|PNLND|LACRX|BROO|DRSCL|NOOSA|OVFOGL|OVF|MBO)\b"#, options: [.regularExpression, .caseInsensitive]) != nil)
    }

    private func shouldImport(_ candidate: ReceiptCandidate, allowUnknownWhenPriced: Bool) -> Bool {
        guard candidate.price != nil, !isNonFoodProduct(candidate), !isModifierOnlyName(candidate.name) else { return false }

        let profile = LocalFoodKnowledge.profile(for: candidate.name)
        if profile.category != .unknown { return true }

        if candidate.taxCode?.uppercased() == "T" { return false }
        if containsFoodKeyword(candidate.name) { return true }
        if candidate.taxCode?.uppercased() == "F" { return true }

        return allowUnknownWhenPriced
    }

    private func containsFoodKeyword(_ name: String) -> Bool {
        let normalized = LocalFoodKnowledge.normalize(name)
        return Self.foodKeywords.contains { normalized.contains($0) }
    }

    private func isNonFoodProduct(_ candidate: ReceiptCandidate) -> Bool {
        isNonFoodProductName(candidate.name) || isNonFoodProductName(candidate.rawLine)
    }

    private func isNonFoodProductName(_ name: String) -> Bool {
        let patterns = [
            #"\b(BOTTLE\s*DEPOSIT|BOTTLE\s*DEP|DEPOSIT)\b"#,
            #"BOTTLEDEPOSIT"#,
            #"\b(PAPER\s*TOWELS?|TOWELS?|NAPKINS?|TISSUE|TOILET\s*PAPER)\b"#,
            #"\b(SOAP|SHAMPOO|DETERGENT|CLEANER|SPONGE|FOIL|PLASTIC\s*WRAP)\b"#,
            #"\b(REUSABLE\s*BAG|PAPER\s*BAG|BAG\s*FEE)\b"#
        ]

        return patterns.contains { name.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil }
    }

    private func isModifierOnlyName(_ name: String) -> Bool {
        let normalized = LocalFoodKnowledge.normalize(name)
        let modifierWords: Set<String> = [
            "whole", "organic", "large", "small", "medium", "fresh", "regular", "bag", "package", "pack"
        ]
        let words = normalized.split(separator: " ").map(String.init)
        return !words.isEmpty && words.allSatisfy { modifierWords.contains($0) }
    }
}
