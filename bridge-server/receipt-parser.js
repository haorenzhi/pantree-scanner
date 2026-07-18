/**
 * Receipt text parser — ported from receipt-scanner/parser.py.
 *
 * Parses raw OCR text into structured food items by filtering non-food lines,
 * extracting prices, normalizing names, and fuzzy-matching against the food DB.
 */

const { FOOD_DB } = require('./food-db');

// Flat key→days map for quick lookup in matchFood
const FOOD_KEYS = Object.keys(FOOD_DB);

// Common receipt abbreviations → expanded form
const ABBREVIATIONS = {
  ORG: 'Organic', GRN: 'Green', BNL: 'Boneless', BNLS: 'Boneless',
  CHKN: 'Chicken', BRST: 'Breast', GRD: 'Ground', GRND: 'Ground',
  BF: 'Beef', VEG: 'Vegetable', FRZ: 'Frozen', FRSH: 'Fresh',
  WHL: 'Whole', LG: 'Large', SM: 'Small', MED: 'Medium',
  PKG: 'Package', BNDL: 'Bundle', YLW: 'Yellow', RED: 'Red',
  WHT: 'White', BLK: 'Black', CRSP: 'Crisp', SWT: 'Sweet',
  LB: '', OZ: '', CT: '', EA: '', PK: '',
};

// Regex patterns for non-food lines to filter out
const NON_FOOD_PATTERNS = [
  /\b(TOTAL|SUBTOTAL|SUB\s*TOTAL|NET\s*SALES)\b/i,
  /\b(TAX|SALES\s*TAX|HST|GST|PST)\b/i,
  /\b(CHANGE|CASH|CREDIT|DEBIT|TENDER|PAYMENT|PAID|BALANCE)\b/i,
  /\b(VISA|MASTERCARD|AMEX|DISCOVER|INTERAC)\b/i,
  /\b(THANK\s*YOU|WELCOME|COME\s*AGAIN|HAVE\s*A)\b/i,
  /\b(STORE|RECEIPT|TRANSACTION|CASHIER|REG)\b/i,
  /\b(MEMBER|LOYALTY|REWARDS|SAVINGS|DISCOUNT|COUPON)\b/i,
  /\b(REFUND|RETURN|VOID|CANCEL)\b/i,
  /\b(TEL|FAX|PHONE|WWW\.|HTTP|\.COM|\.CA)\b/i,
  /\b(DEPOSIT|BOTTLE\s*DEP)\b/i,
  /\b(SOLD\s*ITEMS|ITEMS?\s*SOLD)\b/i,
  /\b(MID|TID|MERCH|TERMINAL|AUTH|APPROVAL)\b/i,
  /\b(MARKET|FOODS?|GROCERY|GROCER|SUPERMARKET)\b/i,
  /\b(AVE|BLVD|ST|RD|DR|SUITE|FLOOR)\b/i,
  /\b(NY|NJ|CA|TX|FL|CT|PA)\s*\d{4,}/i,
  /\b(PAPER\s*TOWEL|NAPKIN|TISSUE|TRASH\s*BAG|DETERGENT|SOAP|CLEANER|SPONGE)\b/i,
  /^\d{6,}$/,
  /^\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4}/,
  /^\d{1,2}:\d{2}/,
  /^[#*]/,
  /^[\-=_]{3,}$/,
  /^\s*\*{3,}/,
];

// Price extraction regexes
const ITEM_PRICE_RE = /^(.+?)\s{2,}\$?(\d+\.\d{2})\s*[A-Z]?\s*$/;
const INLINE_PRICE_RE = /^(.+?)\s+\$(\d+\.\d{2})\s*[A-Z]{0,2}\s*$/;
const QTY_PREFIX_RE = /^\s*\d+\s*[x@]\s*/i;
const WEIGHT_LINE_RE = /^\s*\d+\.?\d*\s*(kg|lb|g|oz)\b/i;

function normalizeName(raw) {
  let name = raw.trim();
  name = name.replace(QTY_PREFIX_RE, '');
  const words = name.split(/\s+/);
  const expanded = [];
  for (const word of words) {
    const upper = word.toUpperCase().replace(/[.,;:]/g, '');
    if (upper in ABBREVIATIONS) {
      const replacement = ABBREVIATIONS[upper];
      if (replacement) expanded.push(replacement);
    } else {
      expanded.push(word);
    }
  }
  name = expanded.join(' ');
  name = name.replace(/\w\S*/g, w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase());
  name = name.replace(/^[.,;:\-*#]+|[.,;:\-*#]+$/g, '');
  return name.trim();
}

function levenshtein(a, b) {
  if (a.length < b.length) return levenshtein(b, a);
  if (b.length === 0) return a.length;
  let prev = Array.from({ length: b.length + 1 }, (_, i) => i);
  for (let i = 0; i < a.length; i++) {
    const curr = [i + 1];
    for (let j = 0; j < b.length; j++) {
      const ins = prev[j + 1] + 1;
      const del = curr[j] + 1;
      const sub = prev[j] + (a[i] !== b[j] ? 1 : 0);
      curr.push(Math.min(ins, del, sub));
    }
    prev = curr;
  }
  return prev[prev.length - 1];
}

function matchFood(name) {
  const lower = name.toLowerCase();

  // 1. Exact match
  if (FOOD_DB[lower]) return lower;

  // 2. Substring match — longest matching key wins
  let bestSub = null;
  let bestLen = 0;
  for (const key of FOOD_KEYS) {
    if (lower.includes(key) && key.length > bestLen) {
      bestSub = key;
      bestLen = key.length;
    }
  }
  if (bestSub && bestLen >= 3) return bestSub;

  // 3. Word-level match — try each word individually
  const words = lower.split(/\s+/).filter(w => w.length >= 3);
  for (const word of words) {
    if (FOOD_DB[word]) return word;
    for (const key of FOOD_KEYS) {
      if ((word.includes(key) || key.includes(word)) && key.length >= 3) return key;
    }
  }

  // 4. Levenshtein fuzzy match on full name (~30% tolerance)
  let bestMatch = null;
  let bestDist = Infinity;
  for (const key of FOOD_KEYS) {
    const dist = levenshtein(lower, key);
    const maxLen = Math.max(lower.length, key.length);
    if (dist < bestDist && dist <= maxLen * 0.3) {
      bestDist = dist;
      bestMatch = key;
    }
  }
  if (bestMatch) return bestMatch;

  // 5. Levenshtein fuzzy match on individual words (~30% tolerance)
  for (const word of words) {
    for (const key of FOOD_KEYS) {
      const dist = levenshtein(word, key);
      const maxLen = Math.max(word.length, key.length);
      if (dist < bestDist && dist <= maxLen * 0.3) {
        bestDist = dist;
        bestMatch = key;
      }
    }
  }
  return bestMatch;
}

function parseReceipt(rawText) {
  const lines = rawText.split('\n');
  const items = [];
  const seen = new Set();

  for (const line of lines) {
    const stripped = line.trim();
    if (!stripped) continue;

    if (stripped.length < 3) continue;
    if (NON_FOOD_PATTERNS.some(p => p.test(stripped))) continue;
    if (WEIGHT_LINE_RE.test(stripped)) continue;

    let name = null;
    let price = null;

    const priceMatch = ITEM_PRICE_RE.exec(stripped) || INLINE_PRICE_RE.exec(stripped);
    if (priceMatch) {
      name = priceMatch[1];
      price = parseFloat(priceMatch[2]) || null;
    } else if (/[a-zA-Z]{2,}/.test(stripped)) {
      name = stripped;
    }

    if (!name) continue;

    name = normalizeName(name);
    if (name.length < 2) continue;

    const key = name.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);

    const matched = matchFood(name);
    if (matched) {
      const entry = FOOD_DB[matched];
      const canonical = matched.replace(/\b\w/g, c => c.toUpperCase());
      items.push({ name: canonical, price, section: entry.section, exp_days: entry.days });
    }
  }

  return items;
}

module.exports = { parseReceipt };
