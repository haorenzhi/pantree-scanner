const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const Tesseract = require('tesseract.js');

const app = express();
const PORT = process.env.PORT || 4000;
const DATA_FILE = path.join(__dirname, 'pantree-data.json');

app.use(cors());
app.use(express.json());

// Multer — in-memory storage for uploaded receipt images (max 10 MB)
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } });

// --- Data helpers ---

function readData() {
  try {
    if (fs.existsSync(DATA_FILE)) {
      return JSON.parse(fs.readFileSync(DATA_FILE, 'utf-8'));
    }
  } catch (e) {
    console.error('[bridge] Error reading data file:', e.message);
  }
  return {};
}

function writeData(data) {
  fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2));
}

// Emoji lookup — simple mapping of common food names to emojis
const FOOD_EMOJIS = {
  apples: '🍎', apple: '🍎', bananas: '🍌', banana: '🍌',
  blueberries: '🫐', strawberries: '🍓', grapes: '🍇',
  raspberries: '🍓', peaches: '🍑', pears: '🍐',
  lemon: '🍋', lime: '🍋', melons: '🍈', kiwi: '🥝',
  avocados: '🥑', avocado: '🥑', mangos: '🥭', mango: '🥭',
  papaya: '🥭', nectarines: '🍑', cherries: '🍒',
  broccoli: '🥦', carrots: '🥕', corn: '🌽',
  lettuce: '🥬', spinach: '🥬', tomatoes: '🍅', tomato: '🍅',
  potatoes: '🥔', potato: '🥔', onions: '🧅', onion: '🧅',
  garlic: '🧄', peppers: '🌶️', mushrooms: '🍄',
  cucumbers: '🥒', eggplant: '🍆', cauliflower: '🥦',
  celery: '🥬', asparagus: '🥬', squash: '🥒',
  'bok choy': '🥬', 'brussel sprouts': '🥬', okra: '🥬',
  radishes: '🥬', beets: '🥬', artichokes: '🥬',
  chicken: '🍗', 'fried chicken': '🍗', turkey: '🦃',
  steak: '🥩', 'ground beef': '🥩', bacon: '🥓',
  pork: '🥩', 'ground pork': '🥩', 'ground turkey': '🥩',
  ham: '🍖', sausage: '🌭', 'lamb chop': '🥩',
  salmon: '🐟', tilapia: '🐟', bass: '🐟',
  shrimp: '🦐', lobster: '🦞', crab: '🦀',
  scallops: '🐚', squid: '🦑', mussels: '🐚',
  oysters: '🦪', shellfish: '🐚',
  milk: '🥛', eggs: '🥚', egg: '🥚', butter: '🧈',
  cheese: '🧀', 'cream cheese': '🧀', 'cottage cheese': '🧀',
  'ricotta cheese': '🧀', yogurt: '🥛', 'sour cream': '🥛',
  'heavy cream': '🥛', 'half-and-half': '🥛',
  bread: '🍞', bagels: '🥯', pancakes: '🥞', waffles: '🧇',
  rice: '🍚', beans: '🫘', cereal: '🥣', coffee: '☕',
  juice: '🧃', 'orange juice': '🍊', 'apple juice': '🧃',
  'mango juice': '🧃',
  ketchup: '🍅', mustard: '🟡', mayonnaise: '🥫',
  salsa: '🫙', 'soy sauce': '🫙', vinegar: '🫙',
  'olive oil': '🫒', 'maple syrup': '🍁', 'chocolate syrup': '🍫',
  tofu: '🥡', tempeh: '🥡', miso: '🥣',
  guacamole: '🥑', sandwich: '🥪', burrito: '🌯',
  cheesecake: '🍰',
  cilantro: '🌿', chives: '🌿', ginger: '🫚',
};

function resolveEmoji(name) {
  const lower = name.toLowerCase();
  if (FOOD_EMOJIS[lower]) return FOOD_EMOJIS[lower];
  // Partial match
  for (const [key, emoji] of Object.entries(FOOD_EMOJIS)) {
    if (lower.includes(key) || key.includes(lower)) return emoji;
  }
  return '🍽️';
}

// --- Receipt Parser (ported from receipt-scanner/parser.py) ---

const RECEIPT_ABBREVIATIONS = {
  ORG: 'Organic', GRN: 'Green', BNL: 'Boneless', BNLS: 'Boneless',
  CHKN: 'Chicken', BRST: 'Breast', GRD: 'Ground', GRND: 'Ground',
  BF: 'Beef', VEG: 'Vegetable', FRZ: 'Frozen', FRSH: 'Fresh',
  WHL: 'Whole', LG: 'Large', SM: 'Small', MED: 'Medium',
  PKG: 'Package', BNDL: 'Bundle', YLW: 'Yellow', RED: 'Red',
  WHT: 'White', BLK: 'Black', CRSP: 'Crisp', SWT: 'Sweet',
  LB: '', OZ: '', CT: '', EA: '', PK: '',
};

const NON_FOOD_PATTERNS = [
  /\b(TOTAL|SUBTOTAL|SUB\s*TOTAL)\b/i,
  /\b(TAX|SALES\s*TAX|HST|GST|PST)\b/i,
  /\b(CHANGE|CASH|CREDIT|DEBIT|TENDER|PAYMENT)\b/i,
  /\b(VISA|MASTERCARD|AMEX|DISCOVER|INTERAC)\b/i,
  /\b(THANK\s*YOU|WELCOME|COME\s*AGAIN|HAVE\s*A)\b/i,
  /\b(STORE|RECEIPT|TRANSACTION|CASHIER|REG)\b/i,
  /\b(MEMBER|LOYALTY|REWARDS|SAVINGS|DISCOUNT|COUPON)\b/i,
  /\b(REFUND|RETURN|VOID|CANCEL)\b/i,
  /\b(TEL|FAX|PHONE|WWW\.|HTTP|\.COM|\.CA)\b/i,
  /^\d{6,}$/,           // barcode numbers
  /^\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4}/, // dates
  /^\d{1,2}:\d{2}/,     // times
  /^[#*]/,              // metadata lines
  /^[\-=_]{3,}$/,       // separator lines
  /^\s*\*{3,}/,         // asterisk separators
];

const ITEM_PRICE_RE = /^(.+?)\s{2,}\$?(\d+\.\d{2})\s*[A-Z]?\s*$/;
const QTY_PREFIX_RE = /^\s*\d+\s*[x@]\s*/i;
const WEIGHT_LINE_RE = /^\s*\d+\.?\d*\s*(kg|lb|g|oz)\b/i;

function normalizeName(raw) {
  let name = raw.trim();
  // Remove quantity prefixes
  name = name.replace(QTY_PREFIX_RE, '');
  // Expand abbreviations
  const words = name.split(/\s+/);
  const expanded = [];
  for (const word of words) {
    const upper = word.toUpperCase().replace(/[.,;:]/g, '');
    if (upper in RECEIPT_ABBREVIATIONS) {
      const replacement = RECEIPT_ABBREVIATIONS[upper];
      if (replacement) expanded.push(replacement);
    } else {
      expanded.push(word);
    }
  }
  name = expanded.join(' ');
  // Title case
  name = name.replace(/\w\S*/g, w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase());
  // Strip leading/trailing punctuation
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
  const keys = Object.keys(FRIDGE_EXPIRY);

  // 1. Exact match
  for (const key of keys) {
    if (key === lower) return key;
  }

  // 2. Substring match — longest matching key wins
  let bestSub = null;
  let bestLen = 0;
  for (const key of keys) {
    if (lower.includes(key) && key.length > bestLen) {
      bestSub = key;
      bestLen = key.length;
    }
  }
  if (bestSub && bestLen >= 3) return bestSub;

  // 3. Levenshtein fuzzy match (~30% tolerance)
  let bestMatch = null;
  let bestDist = Infinity;
  for (const key of keys) {
    const dist = levenshtein(lower, key);
    const maxLen = Math.max(lower.length, key.length);
    if (dist < bestDist && dist <= maxLen * 0.3) {
      bestDist = dist;
      bestMatch = key;
    }
  }
  return bestMatch; // null if nothing matched
}

function parseReceipt(rawText) {
  const lines = rawText.split('\n');
  const items = [];
  const seen = new Set();

  for (const line of lines) {
    const stripped = line.trim();
    if (!stripped) continue;

    // Skip non-food lines
    if (stripped.length < 3) continue;
    if (NON_FOOD_PATTERNS.some(p => p.test(stripped))) continue;

    // Skip weight/measurement sub-lines
    if (WEIGHT_LINE_RE.test(stripped)) continue;

    // Extract item name and optional price
    let name = null;
    let price = null;

    const priceMatch = ITEM_PRICE_RE.exec(stripped);
    if (priceMatch) {
      name = priceMatch[1];
      price = parseFloat(priceMatch[2]) || null;
    } else if (/[a-zA-Z]{2,}/.test(stripped)) {
      name = stripped;
    }

    if (!name) continue;

    // Normalize
    name = normalizeName(name);
    if (name.length < 2) continue;

    // Deduplicate
    const key = name.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);

    // Fuzzy match against FRIDGE_EXPIRY
    const matched = matchFood(name);
    if (matched) {
      // Use canonical name (title case)
      const canonical = matched.replace(/\b\w/g, c => c.toUpperCase());
      items.push({ name: canonical, price, section: 'fridge', exp_days: FRIDGE_EXPIRY[matched] });
    } else {
      items.push({ name, price, section: 'fridge', exp_days: 7 });
    }
  }

  return items;
}

// --- API Routes ---

// GET /api/foods — return all foods
app.get('/api/foods', (req, res) => {
  const foods = readData();
  res.json(foods);
});

// POST /api/foods — add foods (from scanner or app)
app.post('/api/foods', (req, res) => {
  const { foods } = req.body;
  if (!foods || !Array.isArray(foods)) {
    return res.status(400).json({ error: 'Request body must have a "foods" array' });
  }

  const data = readData();
  let added = 0;

  for (const food of foods) {
    if (!food.id || !food.name) continue;

    // Resolve emoji if not provided
    if (!food.icon) {
      food.icon = resolveEmoji(food.name);
    }

    data[food.id] = food;
    added++;
  }

  writeData(data);
  console.log(`[bridge] Added ${added} food(s). Total: ${Object.keys(data).length}`);
  res.json({ added, total: Object.keys(data).length });
});

// PUT /api/foods/:id — update a single food item
app.put('/api/foods/:id', (req, res) => {
  const data = readData();
  const id = req.params.id;
  const food = req.body;

  if (!food || !food.name) {
    return res.status(400).json({ error: 'Request body must be a food object with a name' });
  }

  food.id = parseInt(id) || id;
  if (!food.icon) {
    food.icon = resolveEmoji(food.name);
  }

  data[id] = food;
  writeData(data);
  res.json({ updated: id });
});

// DELETE /api/foods/:id — delete a food item
app.delete('/api/foods/:id', (req, res) => {
  const data = readData();
  const id = req.params.id;

  if (data[id]) {
    delete data[id];
    writeData(data);
    console.log(`[bridge] Deleted food ${id}. Total: ${Object.keys(data).length}`);
    res.json({ deleted: id, total: Object.keys(data).length });
  } else {
    res.status(404).json({ error: `Food ${id} not found` });
  }
});

// Fridge expiry defaults (days) — subset from expiry_dates.js
const FRIDGE_EXPIRY = {
  apples: 21, blueberries: 7, broccoli: 7, cauliflower: 7,
  cilantro: 3, chives: 3, lemon: 21, lime: 21, lettuce: 5,
  grapes: 7, melons: 4, pears: 4, artichokes: 14, beets: 10,
  eggplant: 4, garlic: 10, ginger: 14, onions: 60, potatoes: 14,
  squash: 14, tomatoes: 7, ketchup: 365, 'maple syrup': 365,
  mayonnaise: 75, mustard: 365, 'olive oil': 365, salsa: 365,
  'soy sauce': 1095, vinegar: 730, rice: 730, bacon: 14,
  chicken: 2, 'ground pork': 2, salmon: 2, tilapia: 2, bass: 2,
  pork: 3, shrimp: 2, shellfish: 2, steak: 3, mushrooms: 7,
  raspberries: 3, strawberries: 3, butter: 90, 'cream cheese': 60,
  eggs: 35, 'heavy cream': 30, milk: 7, 'sour cream': 21,
  tofu: 21, yogurt: 10, 'half-and-half': 4, 'ricotta cheese': 7,
  'cottage cheese': 7, cheese: 7, juice: 21, 'orange juice': 21,
  'apple juice': 21, 'mango juice': 21, miso: 90, scallops: 2,
  squid: 2, 'ground beef': 2, 'lamb chop': 5, lobster: 2,
  crab: 2, mussels: 2, oysters: 2, sausage: 15, ham: 7,
  turkey: 2, 'ground turkey': 2, 'fried chicken': 4,
  avocados: 4, bananas: 2, kiwi: 4, papaya: 7, mangos: 7,
  peaches: 4, nectarines: 4, asparagus: 4, 'bok choy': 3,
  'brussel sprouts': 5, carrots: 21, celery: 14, corn: 2,
  cucumbers: 5, okra: 3, peppers: 5, radishes: 12, spinach: 2,
  guacamole: 4, sandwich: 4, burrito: 4, bread: 7, bagels: 14,
  pancakes: 4, waffles: 4, tempeh: 14, cheesecake: 7,
  beans: 365, cereal: 365, coffee: 14, 'chocolate syrup': 365,
};

function lookupFridgeExpiry(name) {
  const lower = name.toLowerCase();
  if (FRIDGE_EXPIRY[lower] !== undefined) return FRIDGE_EXPIRY[lower];
  for (const [key, days] of Object.entries(FRIDGE_EXPIRY)) {
    if (lower.includes(key) || key.includes(lower)) return days;
  }
  return 7; // default 7 days
}

// POST /api/fridge — quick-add a single item to the fridge
// Body: { "name": "Milk" }  (only name is required)
app.post('/api/fridge', (req, res) => {
  const { name } = req.body;
  if (!name) {
    return res.status(400).json({ error: '"name" is required' });
  }

  const id = Math.floor(10000 + Math.random() * 90000);
  const today = new Date().toISOString().slice(0, 10);
  const expiryDays = lookupFridgeExpiry(name);
  const expDate = new Date(Date.now() + expiryDays * 86400000)
    .toISOString().slice(0, 10);

  const food = {
    id,
    name,
    icon: resolveEmoji(name),
    buyDate: today,
    expDate,
    section: 'fridge',
  };

  const data = readData();
  data[id] = food;
  writeData(data);

  console.log(`[bridge] Fridge: added "${name}" (expires ${expDate})`);
  res.json({ added: food });
});

// --- Receipt Scanner ---

// POST /api/scan — upload receipt image, OCR it, parse, and add items
app.post('/api/scan', upload.single('receipt'), async (req, res) => {
  if (!req.file) {
    console.log(`[scan] ✗ No image in request`);
    return res.status(400).json({ error: 'No image uploaded. Use field name "receipt".' });
  }

  const t0 = Date.now();
  console.log(`[scan] ── Upload received ──`);
  console.log(`[scan]   File: ${req.file.originalname} (${(req.file.size / 1024).toFixed(0)} KB, ${req.file.mimetype})`);

  try {
    // OCR the image buffer (use local lang-data to avoid network fetch)
    console.log(`[scan]   Running Tesseract OCR...`);
    const langPath = path.join(__dirname, 'lang-data');
    const { data: { text } } = await Tesseract.recognize(req.file.buffer, 'eng', { langPath });
    const ocrMs = Date.now() - t0;
    const lines = text.split('\n');
    console.log(`[scan]   OCR done in ${(ocrMs / 1000).toFixed(1)}s — ${lines.length} lines`);
    console.log(`[scan]   ── Raw OCR text ──`);
    for (const line of lines) {
      if (line.trim()) console.log(`[scan]   | ${line}`);
    }

    // Parse receipt text into food items
    console.log(`[scan]   ── Parsing receipt ──`);
    const parsed = parseReceipt(text);
    console.log(`[scan]   Parsed ${parsed.length} item(s) from ${lines.filter(l => l.trim()).length} non-empty lines`);
    for (const item of parsed) {
      console.log(`[scan]     • ${item.name} (exp ${item.exp_days}d, ${item.section})${item.price != null ? ' $' + item.price.toFixed(2) : ''}`);
    }

    // Build food objects and write to data file
    console.log(`[scan]   ── Writing to pantree-data.json ──`);
    const data = readData();
    const today = new Date().toISOString().slice(0, 10);
    const addedItems = [];

    for (const item of parsed) {
      const id = Math.floor(10000 + Math.random() * 90000);
      const expDate = new Date(Date.now() + item.exp_days * 86400000)
        .toISOString().slice(0, 10);

      const food = {
        id,
        name: item.name,
        icon: resolveEmoji(item.name),
        buyDate: today,
        expDate,
        section: item.section,
      };

      data[id] = food;
      addedItems.push(food);
      console.log(`[scan]     + [${id}] ${food.icon} ${food.name} (expires ${expDate})`);
    }

    writeData(data);
    const totalMs = Date.now() - t0;
    console.log(`[scan]   ── Done ── ${addedItems.length} item(s) added, ${Object.keys(data).length} total in DB, ${(totalMs / 1000).toFixed(1)}s elapsed`);

    res.json({ added: addedItems.length, items: addedItems });
  } catch (err) {
    const totalMs = Date.now() - t0;
    console.error(`[scan]   ✗ Error after ${(totalMs / 1000).toFixed(1)}s: ${err.message}`);
    console.error(err.stack);
    res.status(500).json({ error: 'OCR/parsing failed: ' + err.message });
  }
});

// GET /scan — mobile-friendly upload page
app.get('/scan', (req, res) => {
  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Pantree Receipt Scanner</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
           background: #f5f5f5; color: #333; padding: 20px; max-width: 480px; margin: 0 auto; }
    h1 { font-size: 1.5rem; margin-bottom: 4px; }
    .subtitle { color: #666; font-size: 0.9rem; margin-bottom: 20px; }
    .upload-area { background: #fff; border: 2px dashed #ccc; border-radius: 12px;
                   padding: 40px 20px; text-align: center; margin-bottom: 16px; cursor: pointer; }
    .upload-area:active { border-color: #4CAF50; background: #f9fff9; }
    .upload-area .icon { font-size: 3rem; margin-bottom: 8px; }
    .upload-area p { color: #666; }
    input[type="file"] { display: none; }
    .btn { display: block; width: 100%; padding: 14px; background: #4CAF50; color: #fff;
           border: none; border-radius: 8px; font-size: 1.1rem; cursor: pointer; margin-bottom: 16px; }
    .btn:disabled { background: #ccc; cursor: not-allowed; }
    .status { text-align: center; padding: 12px; border-radius: 8px; margin-bottom: 16px; display: none; }
    .status.loading { display: block; background: #fff3cd; color: #856404; }
    .status.success { display: block; background: #d4edda; color: #155724; }
    .status.error { display: block; background: #f8d7da; color: #721c24; }
    .results { list-style: none; }
    .results li { background: #fff; padding: 12px 16px; border-radius: 8px;
                  margin-bottom: 8px; display: flex; align-items: center; gap: 10px;
                  box-shadow: 0 1px 3px rgba(0,0,0,0.08); }
    .results .emoji { font-size: 1.5rem; }
    .results .name { flex: 1; font-weight: 500; }
    .results .exp { color: #888; font-size: 0.85rem; }
    .preview { max-width: 100%; max-height: 200px; border-radius: 8px; margin-bottom: 16px; display: none; }
  </style>
</head>
<body>
  <h1>Pantree Receipt Scanner</h1>
  <p class="subtitle">Take a photo of your grocery receipt to add items</p>

  <div class="upload-area" id="uploadArea">
    <div class="icon">📷</div>
    <p>Tap to take a photo or choose an image</p>
  </div>
  <input type="file" id="fileInput" accept="image/*">
  <img class="preview" id="preview">
  <button class="btn" id="scanBtn" disabled>Scan Receipt</button>
  <div class="status" id="status"></div>
  <ul class="results" id="results"></ul>

  <script>
    const uploadArea = document.getElementById('uploadArea');
    const fileInput = document.getElementById('fileInput');
    const preview = document.getElementById('preview');
    const scanBtn = document.getElementById('scanBtn');
    const status = document.getElementById('status');
    const results = document.getElementById('results');

    let selectedFile = null;

    uploadArea.addEventListener('click', () => fileInput.click());

    fileInput.addEventListener('change', (e) => {
      const file = e.target.files[0];
      if (!file) return;
      selectedFile = file;
      preview.src = URL.createObjectURL(file);
      preview.style.display = 'block';
      scanBtn.disabled = false;
      results.innerHTML = '';
      status.className = 'status';
    });

    scanBtn.addEventListener('click', async () => {
      if (!selectedFile) return;
      scanBtn.disabled = true;
      status.className = 'status loading';
      status.textContent = 'Scanning receipt... OCR may take 10\\u201330 seconds.';
      results.innerHTML = '';

      const form = new FormData();
      form.append('receipt', selectedFile);

      try {
        const res = await fetch('/api/scan', { method: 'POST', body: form });
        const data = await res.json();

        if (!res.ok) throw new Error(data.error || 'Scan failed');

        status.className = 'status success';
        status.textContent = 'Added ' + data.added + ' item(s) to Pantree!';

        for (const item of data.items) {
          const li = document.createElement('li');
          li.innerHTML = '<span class="emoji">' + item.icon + '</span>'
            + '<span class="name">' + item.name + '</span>'
            + '<span class="exp">exp ' + item.expDate + '</span>';
          results.appendChild(li);
        }
      } catch (err) {
        status.className = 'status error';
        status.textContent = 'Error: ' + err.message;
      }

      scanBtn.disabled = false;
    });
  </script>
</body>
</html>`);
});

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', foods: Object.keys(readData()).length });
});

// --- Start server ---

app.listen(PORT, () => {
  // Initialize data file if it doesn't exist
  if (!fs.existsSync(DATA_FILE)) {
    writeData({});
    console.log(`[bridge] Created empty data file: ${DATA_FILE}`);
  }
  console.log(`[bridge] Pantree bridge server running on http://localhost:${PORT}`);
  console.log(`[bridge] Data file: ${DATA_FILE}`);
  console.log(`[bridge] Endpoints:`);
  console.log(`[bridge]   GET    /api/foods      - list all foods`);
  console.log(`[bridge]   POST   /api/foods      - add foods (scanner)`);
  console.log(`[bridge]   POST   /api/fridge     - quick-add one item to fridge`);
  console.log(`[bridge]   PUT    /api/foods/:id  - update a food`);
  console.log(`[bridge]   DELETE /api/foods/:id  - delete a food`);
  console.log(`[bridge]   POST   /api/scan       - upload receipt image (OCR)`);
  console.log(`[bridge]   GET    /scan           - mobile receipt scanner UI`);
  console.log(`[bridge]   GET    /api/health     - health check`);
});
