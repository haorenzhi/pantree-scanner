const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const Tesseract = require('tesseract.js');

const { resolveEmoji, lookupExpiry, lookupSection } = require('./food-db');
const { parseReceipt } = require('./receipt-parser');

const app = express();
const PORT = process.env.PORT || 4000;
const DATA_FILE = path.join(__dirname, 'pantree-data.json');

app.use(cors());
app.use(express.json());

// Serve React frontend static files (build/ folder)
const buildPath = path.join(__dirname, '..', 'build');
if (fs.existsSync(buildPath)) {
  app.use(express.static(buildPath));
}

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

// POST /api/fridge — quick-add a single item
app.post('/api/fridge', (req, res) => {
  const { name } = req.body;
  if (!name) {
    return res.status(400).json({ error: '"name" is required' });
  }

  const id = Math.floor(10000 + Math.random() * 90000);
  const today = new Date().toISOString().slice(0, 10);
  const expiryDays = lookupExpiry(name);
  const expDate = new Date(Date.now() + expiryDays * 86400000)
    .toISOString().slice(0, 10);

  const food = {
    id,
    name,
    icon: resolveEmoji(name),
    buyDate: today,
    expDate,
    section: lookupSection(name),
  };

  const data = readData();
  data[id] = food;
  writeData(data);

  console.log(`[bridge] Added "${name}" → ${food.section} (expires ${expDate})`);
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
      console.log(`[scan]     • ${item.name} → ${item.section} (exp ${item.exp_days}d)${item.price != null ? ' $' + item.price.toFixed(2) : ''}`);
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
        price: item.price,
        buyDate: today,
        expDate,
        section: item.section,
      };

      data[id] = food;
      addedItems.push(food);
      console.log(`[scan]     + [${id}] ${food.icon} ${food.name} → ${food.section} (expires ${expDate})`);
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

// Catch-all: serve React app for any non-API route
if (fs.existsSync(buildPath)) {
  app.get('*', (req, res) => {
    res.sendFile(path.join(buildPath, 'index.html'));
  });
}

app.listen(PORT, () => {
  if (!fs.existsSync(DATA_FILE)) {
    writeData({});
    console.log(`[bridge] Created empty data file: ${DATA_FILE}`);
  }
  console.log(`[bridge] Pantree bridge server running on http://localhost:${PORT}`);
  console.log(`[bridge] Data file: ${DATA_FILE}`);
  console.log(`[bridge] Endpoints:`);
  console.log(`[bridge]   GET    /api/foods      - list all foods`);
  console.log(`[bridge]   POST   /api/foods      - add foods (scanner)`);
  console.log(`[bridge]   POST   /api/fridge     - quick-add one item`);
  console.log(`[bridge]   PUT    /api/foods/:id  - update a food`);
  console.log(`[bridge]   DELETE /api/foods/:id  - delete a food`);
  console.log(`[bridge]   POST   /api/scan       - upload receipt image (OCR)`);
  console.log(`[bridge]   GET    /scan           - mobile receipt scanner UI`);
  console.log(`[bridge]   GET    /api/health     - health check`);
});
