"""
Receipt text parser.

Parses raw OCR text from a grocery receipt into structured food items.
Handles filtering of non-food lines, price extraction, name normalization,
and fuzzy matching against the Pantree expiry database.
"""

import re

# Expiry database — mirrors src/components/expiry_dates.js
EXPIRY_DB = [
    {"name": "Apples", "fridge": 21, "shelf": 2, "freezer": 240},
    {"name": "Blueberries", "fridge": 7, "shelf": 2, "freezer": 365},
    {"name": "Broccoli", "fridge": 7, "shelf": 2, "freezer": 365},
    {"name": "Cauliflower", "fridge": 7, "shelf": 2, "freezer": 240},
    {"name": "Cilantro", "fridge": 3, "shelf": 2, "freezer": 150},
    {"name": "Chives", "fridge": 3, "shelf": 2, "freezer": 150},
    {"name": "Lemon", "fridge": 21, "shelf": 2, "freezer": 160},
    {"name": "Lime", "fridge": 21, "shelf": 2, "freezer": 160},
    {"name": "Lettuce", "fridge": 5, "shelf": 2, "freezer": 180},
    {"name": "Grapes", "fridge": 7, "shelf": 1, "freezer": 365},
    {"name": "Melons", "fridge": 4, "shelf": 2, "freezer": 365},
    {"name": "Pears", "fridge": 4, "shelf": 5, "freezer": 365},
    {"name": "Artichokes", "fridge": 14, "shelf": 2, "freezer": 365},
    {"name": "Beets", "fridge": 10, "shelf": 1, "freezer": 540},
    {"name": "Eggplant", "fridge": 4, "shelf": 1, "freezer": 240},
    {"name": "Garlic", "fridge": 10, "shelf": 30, "freezer": 365},
    {"name": "Ginger", "fridge": 14, "shelf": 2, "freezer": 90},
    {"name": "Onions", "fridge": 60, "shelf": 21, "freezer": 365},
    {"name": "Potatoes", "fridge": 14, "shelf": 45, "freezer": 365},
    {"name": "Squash", "fridge": 14, "shelf": 7, "freezer": 365},
    {"name": "Tomatoes", "fridge": 7, "shelf": 3, "freezer": 90},
    {"name": "Ketchup", "fridge": 365, "shelf": 182, "freezer": 0},
    {"name": "Maple Syrup", "fridge": 365, "shelf": 365, "freezer": 0},
    {"name": "Mayonnaise", "fridge": 75, "shelf": 60, "freezer": 0},
    {"name": "Mustard", "fridge": 365, "shelf": 30, "freezer": 0},
    {"name": "Olive Oil", "fridge": 365, "shelf": 182, "freezer": 0},
    {"name": "Salsa", "fridge": 365, "shelf": 30, "freezer": 0},
    {"name": "Soy Sauce", "fridge": 1095, "shelf": 365, "freezer": 0},
    {"name": "Vinegar", "fridge": 730, "shelf": 365, "freezer": 0},
    {"name": "Rice", "fridge": 730, "shelf": 365, "freezer": 240},
    {"name": "Bacon", "fridge": 14, "shelf": 2, "freezer": 240},
    {"name": "Chicken", "fridge": 2, "shelf": 0, "freezer": 270},
    {"name": "Ground Pork", "fridge": 2, "shelf": 0, "freezer": 120},
    {"name": "Salmon", "fridge": 2, "shelf": 0, "freezer": 365},
    {"name": "Tilapia", "fridge": 2, "shelf": 0, "freezer": 240},
    {"name": "Bass", "fridge": 2, "shelf": 0, "freezer": 90},
    {"name": "Pork", "fridge": 3, "shelf": 0, "freezer": 180},
    {"name": "Shrimp", "fridge": 2, "shelf": 0, "freezer": 150},
    {"name": "Shellfish", "fridge": 2, "shelf": 0, "freezer": 90},
    {"name": "Steak", "fridge": 3, "shelf": 0, "freezer": 180},
    {"name": "Mushrooms", "fridge": 7, "shelf": 0, "freezer": 365},
    {"name": "Raspberries", "fridge": 3, "shelf": 0, "freezer": 365},
    {"name": "Strawberries", "fridge": 3, "shelf": 0, "freezer": 365},
    {"name": "Butter", "fridge": 90, "shelf": 0, "freezer": 180},
    {"name": "Cream Cheese", "fridge": 60, "shelf": 14, "freezer": 60},
    {"name": "Eggs", "fridge": 35, "shelf": 0, "freezer": 365},
    {"name": "Heavy Cream", "fridge": 30, "shelf": 0, "freezer": 90},
    {"name": "Milk", "fridge": 7, "shelf": 0, "freezer": 150},
    {"name": "Sour Cream", "fridge": 21, "shelf": 0, "freezer": 180},
    {"name": "Tofu", "fridge": 21, "shelf": 7, "freezer": 150},
    {"name": "Yogurt", "fridge": 10, "shelf": 0, "freezer": 45},
    {"name": "Half-and-half", "fridge": 4, "shelf": 0, "freezer": 90},
    {"name": "Ricotta Cheese", "fridge": 7, "shelf": 0, "freezer": 90},
    {"name": "Cottage Cheese", "fridge": 7, "shelf": 0, "freezer": 90},
    {"name": "Cheese", "fridge": 7, "shelf": 0, "freezer": 180},
    {"name": "Juice", "fridge": 21, "shelf": 0, "freezer": 180},
    {"name": "Orange Juice", "fridge": 21, "shelf": 0, "freezer": 180},
    {"name": "Apple Juice", "fridge": 21, "shelf": 0, "freezer": 180},
    {"name": "Mango Juice", "fridge": 21, "shelf": 0, "freezer": 180},
    {"name": "Miso", "fridge": 90, "shelf": 0, "freezer": 180},
    {"name": "Scallops", "fridge": 2, "shelf": 0, "freezer": 150},
    {"name": "Squid", "fridge": 2, "shelf": 0, "freezer": 270},
    {"name": "Ground Beef", "fridge": 2, "shelf": 0, "freezer": 120},
    {"name": "Lamb Chop", "fridge": 5, "shelf": 0, "freezer": 180},
    {"name": "Lobster", "fridge": 2, "shelf": 0, "freezer": 180},
    {"name": "Crab", "fridge": 2, "shelf": 0, "freezer": 180},
    {"name": "Mussels", "fridge": 2, "shelf": 0, "freezer": 90},
    {"name": "Oysters", "fridge": 2, "shelf": 0, "freezer": 365},
    {"name": "Sausage", "fridge": 15, "shelf": 0, "freezer": 60},
    {"name": "Ham", "fridge": 7, "shelf": 0, "freezer": 60},
    {"name": "Turkey", "fridge": 2, "shelf": 0, "freezer": 365},
    {"name": "Ground Turkey", "fridge": 2, "shelf": 0, "freezer": 90},
    {"name": "Fried Chicken", "fridge": 4, "shelf": 0, "freezer": 120},
    {"name": "Avocados", "fridge": 4, "shelf": 7, "freezer": 180},
    {"name": "Bananas", "fridge": 2, "shelf": 7, "freezer": 90},
    {"name": "Kiwi", "fridge": 4, "shelf": 0, "freezer": 365},
    {"name": "Papaya", "fridge": 7, "shelf": 4, "freezer": 365},
    {"name": "Mangos", "fridge": 7, "shelf": 4, "freezer": 365},
    {"name": "Peaches", "fridge": 4, "shelf": 7, "freezer": 240},
    {"name": "Nectarines", "fridge": 4, "shelf": 7, "freezer": 365},
    {"name": "Asparagus", "fridge": 4, "shelf": 0, "freezer": 210},
    {"name": "Bok Choy", "fridge": 3, "shelf": 0, "freezer": 365},
    {"name": "Brussel Sprouts", "fridge": 5, "shelf": 0, "freezer": 365},
    {"name": "Carrots", "fridge": 21, "shelf": 0, "freezer": 365},
    {"name": "Celery", "fridge": 14, "shelf": 0, "freezer": 60},
    {"name": "Corn", "fridge": 2, "shelf": 0, "freezer": 365},
    {"name": "Cucumbers", "fridge": 5, "shelf": 0, "freezer": 240},
    {"name": "Okra", "fridge": 3, "shelf": 0, "freezer": 365},
    {"name": "Peppers", "fridge": 5, "shelf": 0, "freezer": 365},
    {"name": "Radishes", "fridge": 12, "shelf": 0, "freezer": 180},
    {"name": "Spinach", "fridge": 2, "shelf": 0, "freezer": 365},
    {"name": "Guacamole", "fridge": 4, "shelf": 0, "freezer": 180},
    {"name": "Sandwich", "fridge": 4, "shelf": 0, "freezer": 0},
    {"name": "Burrito", "fridge": 4, "shelf": 0, "freezer": 150},
    {"name": "Bread", "fridge": 7, "shelf": 5, "freezer": 180},
    {"name": "Bagels", "fridge": 14, "shelf": 5, "freezer": 90},
    {"name": "Pancakes", "fridge": 4, "shelf": 0, "freezer": 0},
    {"name": "Waffles", "fridge": 4, "shelf": 0, "freezer": 0},
    {"name": "Tempeh", "fridge": 14, "shelf": 0, "freezer": 300},
    {"name": "Cheesecake", "fridge": 7, "shelf": 0, "freezer": 180},
    {"name": "Beans", "fridge": 365, "shelf": 365, "freezer": 540},
    {"name": "Cereal", "fridge": 365, "shelf": 365, "freezer": 730},
    {"name": "Coffee", "fridge": 14, "shelf": 14, "freezer": 730},
    {"name": "Chocolate Syrup", "fridge": 365, "shelf": 365, "freezer": 0},
    {"name": "Coconut Water", "fridge": 7, "shelf": 365, "freezer": 0},
    {"name": "Sweet Potato", "fridge": 14, "shelf": 21, "freezer": 365},
    {"name": "Bell Pepper", "fridge": 5, "shelf": 0, "freezer": 365},
    {"name": "Scallions", "fridge": 7, "shelf": 0, "freezer": 180},
]

# Common receipt abbreviations -> expanded form
ABBREVIATIONS = {
    "ORG": "Organic",
    "OG": "Organic",
    "GRN": "Green",
    "BNL": "Boneless",
    "BNLS": "Boneless",
    "CHKN": "Chicken",
    "BRST": "Breast",
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
    "PKG": "Package",
    "BNDL": "Bundle",
    "YLW": "Yellow",
    "RED": "Red",
    "WHT": "White",
    "BLK": "Black",
    "CRSP": "Crisp",
    "SWT": "Sweet",
    "JMBO": "Jumbo",
    "PNBTR": "Peanut Butter",
    "CHKN": "Chicken",
    "SLCD": "Sliced",
    "SLTD": "Salted",
    "CRNCHY": "Crunchy",
    "YOGHURT": "Yogurt",
    "YGHRT": "Yogurt",
    "LB": "",  # unit, not a word
    "OZ": "",
    "CT": "",
    "EA": "",
    "PK": "",
    "0G": "",  # sometimes OCR reads "OG" as "0G"
}

# Store brand prefixes to strip from item names (e.g., "365" = Whole Foods)
STORE_BRAND_PREFIXES = re.compile(
    r"^(365|KIRKLAND|GV|MMRK|STORE|HEB|TJ|PVLB|PDVG|PNLND|LACRX|BROO|DRSCL|NOOSA|OVFOGL)",
    re.IGNORECASE,
)

# Regex patterns for non-food lines to filter out
NON_FOOD_PATTERNS = [
    re.compile(r"\b(TOTAL|SUBTOTAL|SUB\s*TOTAL)\b", re.IGNORECASE),
    re.compile(r"\b(TAX|SALES\s*TAX|HST|GST|PST)\b", re.IGNORECASE),
    re.compile(r"\b(CHANGE|CASH|CREDIT|DEBIT|TENDER|PAYMENT)\b", re.IGNORECASE),
    re.compile(r"\b(VISA|MASTERCARD|AMEX|DISCOVER|INTERAC)\b", re.IGNORECASE),
    re.compile(r"\b(THANK\s*YOU|WELCOME|COME\s*AGAIN|HAVE\s*A)\b", re.IGNORECASE),
    re.compile(r"\b(STORE|RECEIPT|TRANSACTION|CASHIER|REG)\b", re.IGNORECASE),
    re.compile(r"\b(MEMBER|LOYALTY|REWARDS|SAVINGS|DISCOUNT|COUPON)\b", re.IGNORECASE),
    re.compile(r"\b(REFUND|RETURN|VOID|CANCEL)\b", re.IGNORECASE),
    re.compile(r"\b(TEL|FAX|PHONE|WWW\.|HTTP|\.COM|\.CA)\b", re.IGNORECASE),
    re.compile(r"\b(DEPOSIT|BOTTLE\s*DEP)\b", re.IGNORECASE),
    re.compile(r"\b(NET\s*SALES|SOLD\s*ITEMS|SOLD\s*ITEM|PAID)\b", re.IGNORECASE),
    re.compile(r"\b(MID|TID|TERMINAL|AUTH|APPROVAL|SEQUENCE)\b", re.IGNORECASE),
    re.compile(r"\b(MARKET|FOODS|GROCERY|SUPERMRKT|SUPERMARKET)\b", re.IGNORECASE),
    re.compile(r"^F?CODS\.?$", re.IGNORECASE),  # OCR mangled "FOODS"
    re.compile(r"BRYANT\s*PARK|BPK$", re.IGNORECASE),  # store location
    re.compile(r"^[A-Z]{2,}PARK", re.IGNORECASE),  # joined store location names
    re.compile(r"\d{3}[\-.]\d{3}[\-.]\d{4}"),  # phone numbers (917-728-5700)
    re.compile(r"\b[A-Z]{2}\s*\d{5}\b"),  # state + zip (NY10036)
    re.compile(r"\b\d+\w*\s*(Ave|St|Rd|Blvd|Dr|Ln|Way|Pkwy|Ct)\b", re.IGNORECASE),  # addresses
    re.compile(r"^\d{6,}$"),  # barcode numbers
    re.compile(r"^\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4}"),  # dates
    re.compile(r"^\d{1,2}:\d{2}"),  # times
    re.compile(r"^[#*]"),  # metadata lines
    re.compile(r"^[\-=_]{3,}$"),  # separator lines
    re.compile(r"^\s*\*{3,}"),  # asterisk separators
    re.compile(r"^\d+$"),  # lines that are only numbers
    re.compile(r"NETSALES", re.IGNORECASE),  # joined "NetSales"
    re.compile(r"SOLDITEMS", re.IGNORECASE),  # joined "SoldItems"
    re.compile(r"BOTTLEDEPOSIT", re.IGNORECASE),  # joined "BottleDeposit"
]

# Pattern to extract item name and price from a receipt line
# Matches: ITEM NAME $X.XX  or  ITEM $4.09F  or  ITEM NAME   X.XX T
# Whole Foods uses F = food (non-taxable), T = taxable (non-food)
ITEM_PRICE_PATTERN = re.compile(
    r"^(.+?)\s+\$?(\d+\.\d{2})\s*([FfTt]?)\s*[Tt]?\s*$"
)

# Pattern to detect quantity prefixes like "2 x" or "2@"
QTY_PREFIX_PATTERN = re.compile(r"^\s*\d+\s*[x@]\s*", re.IGNORECASE)

# Pattern for weight-based items like "0.50 kg @  $4.99/kg"
WEIGHT_PATTERN = re.compile(r"^\s*\d+\.?\d*\s*(kg|lb|g|oz)\b", re.IGNORECASE)

# Vowels used for readability/gibberish heuristics
_VOWELS = set("aeiouAEIOU")


def _looks_like_gibberish(name):
    """
    Heuristic check: does this look like OCR noise rather than a real word?

    Catches things like "Sssits", "Aeuee", "A Lt Nn Ae", "Njo731T3646".
    """
    if not name:
        return True

    letters = [c for c in name if c.isalpha()]
    if len(letters) < 3:
        return True

    # Real words are roughly 20-80% vowels; outside that range is usually noise
    vowel_ratio = sum(1 for c in letters if c in _VOWELS) / len(letters)
    if vowel_ratio < 0.2 or vowel_ratio > 0.8:
        return True

    tokens = name.split()

    # Too many tiny fragments (e.g. "A Lt Nn Ae")
    tiny = sum(1 for t in tokens if len(t.strip(".,;:-")) <= 2)
    if len(tokens) >= 3 and tiny >= len(tokens) / 2:
        return True

    # A token mixing letters and digits is almost always an ID/code/weight
    for t in tokens:
        if re.search(r"[A-Za-z]", t) and re.search(r"\d", t):
            return True

    # A long run of consonants suggests OCR noise (e.g. "Qtv", "Tmmf")
    if re.search(r"[bcdfghjklmnpqrstvwxz]{5,}", name, re.IGNORECASE):
        return True

    return False


def _is_non_food_line(line):
    """Check if a line matches any non-food pattern."""
    stripped = line.strip()
    if len(stripped) < 3:
        return True
    for pattern in NON_FOOD_PATTERNS:
        if pattern.search(stripped):
            return True
    return False


def _normalize_name(raw_name):
    """
    Clean up and normalize a food item name from receipt text.
    """
    name = raw_name.strip()

    # Remove quantity prefixes
    name = QTY_PREFIX_PATTERN.sub("", name)

    # Strip a glued organic prefix: "OGGINGER"/"0GGINGER" -> "GINGER",
    # "OGWHITE" -> "WHITE". Whole Foods prints "OG" for organic and OCR
    # often reads the leading "O" as "0".
    name = re.sub(r"^[0Oo][Gg]\s*(?=[A-Za-z])", "", name)

    # Remove trailing currency/price garbage the price extractor couldn't
    # parse, e.g. "LEOONIGN $a.85F" -> "LEOONIGN".
    name = re.sub(r"\s*\$\S*\s*$", "", name)

    # Remove trailing weight/unit suffixes like "85/151LB", "12PK"
    name = re.sub(r"\d+/\d+\s*(?:LB|OZ|KG|G)\b", "", name, flags=re.IGNORECASE)
    name = re.sub(r"\d+\s*(?:PK|CT|OZ|LB|EA)\b", "", name, flags=re.IGNORECASE)

    # Strip known store brand prefixes (e.g., "365WHLMLK" -> "WHLMLK")
    name = STORE_BRAND_PREFIXES.sub("", name).strip()

    # Try to split concatenated uppercase words using known food keywords
    # e.g. "HONEYYOGHURT" -> "HONEY YOGHURT", "GRNDBEEF" -> "GRND BEEF"
    food_keywords = [
        "MILK", "EGGS", "BEEF", "PORK", "CHICKEN", "SALMON", "SHRIMP",
        "YOGURT", "YOGHURT", "CHEESE", "BUTTER", "CREAM",
        "STRAWBERRIES", "BLUEBERRIES", "RASPBERRIES", "GRAPEFRUIT",
        "ROMAINE", "LETTUCE", "SPINACH", "BROCCOLI", "CORN", "SALSA",
        "CHIPS", "TOWELS", "BREAD", "RICE", "BEANS", "JUICE",
        "ALE", "BEER", "WINE", "WATER",
    ]
    name_upper = name.upper()
    for kw in food_keywords:
        idx = name_upper.find(kw)
        if idx > 0 and name[idx - 1] != " ":
            name = name[:idx] + " " + name[idx:]
            name_upper = name.upper()
            break  # one split is usually enough

    # Expand abbreviations
    words = name.split()
    expanded = []
    for word in words:
        upper = word.upper().strip(".,;:")
        if upper in ABBREVIATIONS:
            replacement = ABBREVIATIONS[upper]
            if replacement:  # skip empty replacements (units)
                expanded.append(replacement)
        else:
            expanded.append(word)
    name = " ".join(expanded)

    # Title case
    name = name.strip().title()

    # Remove leading/trailing punctuation
    name = name.strip(".,;:-*#")

    return name.strip()


def _levenshtein_distance(s1, s2):
    """Compute Levenshtein edit distance between two strings."""
    if len(s1) < len(s2):
        return _levenshtein_distance(s2, s1)
    if len(s2) == 0:
        return len(s1)

    prev_row = range(len(s2) + 1)
    for i, c1 in enumerate(s1):
        curr_row = [i + 1]
        for j, c2 in enumerate(s2):
            insertions = prev_row[j + 1] + 1
            deletions = curr_row[j] + 1
            substitutions = prev_row[j] + (c1 != c2)
            curr_row.append(min(insertions, deletions, substitutions))
        prev_row = curr_row

    return prev_row[-1]


def _min_substring_distance(needle, haystack):
    """
    Minimum edit distance between `needle` and ANY substring of `haystack`.

    Lets us find a food name buried inside a concatenated/garbled OCR token,
    e.g. find "carrots" inside "ogloisecarruts". Start positions are free
    (first DP row is all zeros) so only the matched window is scored.
    """
    m, n = len(needle), len(haystack)
    if m == 0:
        return 0
    if n == 0:
        return m

    prev = [0] * (n + 1)  # row 0: matching the empty prefix anywhere is free
    for i in range(1, m + 1):
        curr = [i] + [0] * n
        for j in range(1, n + 1):
            cost = 0 if needle[i - 1] == haystack[j - 1] else 1
            curr[j] = min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost)
        prev = curr

    return min(prev)


def _match_food(name):
    """
    Fuzzy-match a parsed item name against the expiry database.

    Returns:
        (canonical_name, section, exp_days, confidence) or None if no match.
        confidence is one of "exact", "substring", "fuzzy".
    """
    name_lower = name.lower()

    # 1. Exact match
    for entry in EXPIRY_DB:
        if entry["name"].lower() == name_lower:
            section, days = _best_section(entry)
            return entry["name"], section, days, "exact"

    # 2. Substring match (food name appears within the parsed name as a word)
    best_sub = None
    best_sub_len = 0
    for entry in EXPIRY_DB:
        entry_lower = entry["name"].lower()
        # Require a word-boundary match so "bass" doesn't hit "embassy"
        if re.search(r"\b" + re.escape(entry_lower) + r"\b", name_lower) and len(entry_lower) > best_sub_len:
            best_sub = entry
            best_sub_len = len(entry_lower)

    if best_sub and best_sub_len >= 4:
        section, days = _best_section(best_sub)
        return best_sub["name"], section, days, "substring"

    # 3. Levenshtein distance (fuzzy match)
    best_match = None
    best_dist = float("inf")
    for entry in EXPIRY_DB:
        entry_lower = entry["name"].lower()
        dist = _levenshtein_distance(name_lower, entry_lower)
        # Short food names (<=5 chars) are matched strictly to avoid
        # garbage like "Was" -> "Bass"; allow at most 1 edit there.
        if len(entry_lower) <= 5:
            tolerance = 1
        else:
            # Allow ~20% character difference for longer names
            tolerance = max(1, int(len(entry_lower) * 0.2))
        if dist < best_dist and dist <= tolerance:
            best_dist = dist
            best_match = entry

    if best_match:
        section, days = _best_section(best_match)
        return best_match["name"], section, days, "fuzzy"

    # 4. Fuzzy substring: find a food buried inside a garbled/concatenated
    #    token, e.g. "carrots" inside "ogloisecarruts", "pepper" in "redbellfepper".
    #    Only applied to longer food names (>=5 chars) to limit false positives.
    #    Origin/colour adjectives are dropped first so "Chinese" can't be
    #    mis-read as "Chives".
    substring_stopwords = {
        "chinese", "japanese", "korean", "mexican", "italian", "french",
        "thai", "white", "green", "red", "black", "yellow", "brown",
        "baby", "fresh", "organic", "whole", "large", "small", "jumbo",
    }
    tokens = [t for t in re.sub(r"[^a-z ]", " ", name_lower).split()
              if t not in substring_stopwords]
    name_squished = "".join(tokens)
    best_sub_match = None
    best_sub_score = float("inf")
    for entry in EXPIRY_DB:
        food = re.sub(r"[^a-z]", "", entry["name"].lower())
        if len(food) < 5:
            continue
        dist = _min_substring_distance(food, name_squished)
        # Allow ~20% of the food-name length to differ within the window
        tolerance = max(1, int(len(food) * 0.2))
        if dist <= tolerance and dist < best_sub_score:
            best_sub_score = dist
            best_sub_match = entry

    if best_sub_match:
        section, days = _best_section(best_sub_match)
        return best_sub_match["name"], section, days, "fuzzy"

    return None


def _best_section(entry):
    """
    Determine the best storage section for a food item.
    Picks the section with the longest shelf life.
    """
    options = []
    if entry.get("fridge", 0) > 0:
        options.append(("fridge", entry["fridge"]))
    if entry.get("shelf", 0) > 0:
        options.append(("shelf", entry["shelf"]))
    if entry.get("freezer", 0) > 0:
        options.append(("freezer", entry["freezer"]))

    if not options:
        return "fridge", 7  # fallback

    # Sort by days descending, prefer fridge over freezer for fresh items
    options.sort(key=lambda x: x[1], reverse=True)
    # Use fridge as default unless shelf life there is very short
    for section, days in options:
        if section == "fridge":
            return "fridge", days

    return options[0]


def parse_receipt(raw_text, strict=True):
    """
    Parse raw OCR text from a receipt into structured food items.

    Args:
        raw_text: full receipt text (newline-separated lines)
        strict: when True (default), only keep items that match a known food
            in the expiry database and discard OCR noise. Set False to fall
            back to keeping unmatched lines as generic fridge items.

    Returns:
        list of dicts: [{ "name": str, "price": float|None,
                          "section": str, "exp_days": int }, ...]
    """
    lines = raw_text.split("\n")
    items = []
    seen_names = set()

    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue

        # Skip non-food lines
        if _is_non_food_line(stripped):
            continue

        # Skip weight/measurement lines (sub-lines of an item)
        if WEIGHT_PATTERN.match(stripped):
            continue

        # Extract item name and optional price
        name = None
        price = None
        is_taxable = False  # Whole Foods: T = taxable non-food

        match = ITEM_PRICE_PATTERN.match(stripped)
        if match:
            name = match.group(1)
            try:
                price = float(match.group(2))
            except ValueError:
                price = None
            # Whole Foods suffix: F = food, T = taxable (non-food)
            suffix = match.group(3).upper() if match.group(3) else ""
            if suffix == "T":
                is_taxable = True
        else:
            # Try extracting price embedded with $ sign (e.g. "ITEM $4.09F")
            inline_price = re.search(r"\$?(\d+\.\d{2})\s*[FfTt]?\s*$", stripped)
            if inline_price:
                try:
                    price = float(inline_price.group(1))
                except ValueError:
                    pass
                name = stripped[:inline_price.start()].strip()
            # Line without a clear price — treat the whole line as a name
            elif re.search(r"[a-zA-Z]{2,}", stripped):
                name = stripped

        # Skip taxable non-food items (paper towels, alcohol, etc.)
        # but keep items that fuzzy-match a known food
        if is_taxable and name:
            norm = _normalize_name(name)
            if not _match_food(norm):
                continue

        if not name:
            continue

        # Normalize the name
        name = _normalize_name(name)

        # Skip if too short, empty after normalization, or already seen
        if len(name) < 2 or name.lower() in seen_names:
            continue

        # Skip lines that are mostly non-alpha (barcodes, IDs, etc.)
        alpha_ratio = sum(1 for c in name if c.isalpha()) / max(len(name), 1)
        if alpha_ratio < 0.5:
            continue

        # Fuzzy match against expiry database
        match_result = _match_food(name)

        if match_result:
            canonical_name, section, exp_days, confidence = match_result
            # A loose (fuzzy) match on gibberish text is almost always a false
            # positive (e.g. "Was" -> "Bass"); require a high-confidence match.
            if confidence == "fuzzy" and _looks_like_gibberish(name):
                continue
            seen_names.add(name.lower())
            items.append({
                "name": canonical_name,
                "price": price,
                "section": section,
                "exp_days": exp_days,
            })
        elif strict:
            # No known-food match — drop the line instead of inventing an item.
            continue
        else:
            # Lenient fallback: keep readable lines as generic fridge items,
            # but still reject obvious OCR noise.
            if _looks_like_gibberish(name):
                continue
            seen_names.add(name.lower())
            items.append({
                "name": name,
                "price": price,
                "section": "fridge",
                "exp_days": 7,
            })

    return items
