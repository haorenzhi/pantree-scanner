Plan to implement                                                                                                                               │
│                                                                                                                                                 │
│ Receipt Scanner MVP — Full Build Plan                                                                                                           │
│                                                                                                                                                 │
│ Build a physical device (Raspberry Pi + camera + motorized rollers) that scrolls in a grocery receipt, OCRs it with Tesseract, extracts food    │
│ items, and writes them directly into the Pantree app's localStorage.                                                                            │
│                                                                                                                                                 │
│ ---                                                                                                                                             │
│ Architecture Overview                                                                                                                           │
│                                                                                                                                                 │
│ ┌─────────────────────────────────────┐                                                                                                         │
│ │  Physical Device                    │                                                                                                         │
│ │  ┌───────────┐  ┌────────────────┐  │                                                                                                         │
│ │  │ Stepper   │  │ Pi Camera v2   │  │                                                                                                         │
│ │  │ Motor +   │──│ (fixed mount)  │  │                                                                                                         │
│ │  │ Rollers   │  └────────────────┘  │                                                                                                         │
│ │  └───────────┘                      │                                                                                                         │
│ │        │                            │                                                                                                         │
│ │  GPIO ─┘     Raspberry Pi 4/5      │                                                                                                          │
│ │              ┌────────────────────┐  │                                                                                                        │
│ │              │ Python scanner     │  │                                                                                                        │
│ │              │  - motor control   │  │                                                                                                        │
│ │              │  - capture frames  │  │                                                                                                        │
│ │              │  - Tesseract OCR   │  │                                                                                                        │
│ │              │  - item parser     │  │                                                                                                        │
│ │              │  - HTTP POST →     │──│──→ Pantree bridge server                                                                               │
│ │              └────────────────────┘  │    (localhost:3001)                                                                                    │
│ └─────────────────────────────────────┘         │                                                                                               │
│                                                 ▼                                                                                               │
│                                     ┌──────────────────┐                                                                                        │
│                                     │ Pantree React App │                                                                                       │
│                                     │ (localhost:3000)  │                                                                                       │
│                                     │                   │                                                                                       │
│                                     │ localStorage      │                                                                                       │
│                                     │ key: pantree-foods │                                                                                      │
│                                     └──────────────────┘                                                                                        │
│                                                                                                                                                 │
│ Data flow: Receipt → Camera → Tesseract → Item parser → HTTP POST → Bridge server → Puppeteer writes to localStorage → Dispatches               │
│ pantree-storage event → React UI updates live.                                                                                                  │
│                                                                                                                                                 │
│ ---                                                                                                                                             │
│ Phase 1: Hardware Assembly                                                                                                                      │
│                                                                                                                                                 │
│ Parts List                                                                                                                                      │
│ ┌───────────────────────────────────────────────┬───────────────────────┬─────────────┐                                                         │
│ │                     Part                      │        Purpose        │ Approx Cost │                                                         │
│ ├───────────────────────────────────────────────┼───────────────────────┼─────────────┤                                                         │
│ │ Raspberry Pi 4 (2GB+) or Pi 5                 │ Main compute          │ $45-60      │                                                         │
│ ├───────────────────────────────────────────────┼───────────────────────┼─────────────┤                                                         │
│ │ Pi Camera Module v2 (or v3)                   │ Image capture         │ $25-30      │                                                         │
│ ├───────────────────────────────────────────────┼───────────────────────┼─────────────┤                                                         │
│ │ NEMA 17 stepper motor (or 28BYJ-48 + ULN2003) │ Drive rollers         │ $5-12       │                                                         │
│ ├───────────────────────────────────────────────┼───────────────────────┼─────────────┤                                                         │
│ │ A4988 or ULN2003 driver board                 │ Motor control         │ $2-5        │                                                         │
│ ├───────────────────────────────────────────────┼───────────────────────┼─────────────┤                                                         │
│ │ 2x rubber rollers (silicone, ~20mm dia)       │ Grip and feed receipt │ $5-10       │                                                         │
│ ├───────────────────────────────────────────────┼───────────────────────┼─────────────┤                                                         │
│ │ 3D-printed or laser-cut housing               │ Frame + slot          │ $10-20      │                                                         │
│ ├───────────────────────────────────────────────┼───────────────────────┼─────────────┤                                                         │
│ │ LED strip or 2x white LEDs                    │ Even illumination     │ $3-5        │                                                         │
│ ├───────────────────────────────────────────────┼───────────────────────┼─────────────┤                                                         │
│ │ 12V/5V power supply                           │ Power motor + Pi      │ $8-10       │                                                         │
│ ├───────────────────────────────────────────────┼───────────────────────┼─────────────┤                                                         │
│ │ Micro SD card (32GB+)                         │ Pi OS                 │ $8          │                                                         │
│ ├───────────────────────────────────────────────┼───────────────────────┼─────────────┤                                                         │
│ │ Ribbon cable (Pi Camera)                      │ Camera connection     │ included    │                                                         │
│ ├───────────────────────────────────────────────┼───────────────────────┼─────────────┤                                                         │
│ │ Breadboard + jumper wires                     │ Prototyping           │ $5          │                                                         │
│ └───────────────────────────────────────────────┴───────────────────────┴─────────────┘                                                         │
│ Total: ~$120-180                                                                                                                                │
│                                                                                                                                                 │
│ Mechanical Design                                                                                                                               │
│                                                                                                                                                 │
│ Side view:                                                                                                                                      │
│                     ┌──── Camera (pointing down)                                                                                                │
│                     │                                                                                                                           │
│          ┌──────────▼──────────┐                                                                                                                │
│          │    viewing window   │                                                                                                                │
│     ═════╪════════════════════╪═════  ← receipt paper path                                                                                      │
│          │  ┌──┐        ┌──┐  │                                                                                                                 │
│          │  │  │ roller  │  │  │                                                                                                                │
│          │  │  │◄───────►│  │  │                                                                                                                │
│          │  └──┘  motor  └──┘  │                                                                                                                │
│          └─────────────────────┘                                                                                                                │
│                                                                                                                                                 │
│ Steps                                                                                                                                           │
│                                                                                                                                                 │
│ 1. Mount the camera above the paper path, pointing straight down, ~8-10cm away from the paper surface. Use a fixed bracket or 3D-printed mount. │
│  The camera should see the full width of a receipt (~7.5cm / 3 inches).                                                                         │
│ 2. Build the roller feed. Press-fit two silicone rollers onto a shared axle (or use a 3D-printed gear linkage). One roller is driven by the     │
│ stepper motor, the other is an idler that presses against it with a spring or gravity. The gap between rollers should be ~0.5mm (enough to grip │
│  thermal paper).                                                                                                                                │
│ 3. Wire the stepper motor. Connect the 28BYJ-48 to the ULN2003 driver board, and wire the driver's IN1-IN4 pins to GPIO pins 17, 18, 27, 22 on  │
│ the Pi. Power the driver board from 5V.                                                                                                         │
│ 4. Add lighting. Mount 2 white LEDs (or a short LED strip) flanking the camera view area, angled at ~45 degrees to avoid glare on thermal       │
│ paper. Diffuse if possible.                                                                                                                     │
│ 5. Create the housing. A simple box with:                                                                                                       │
│   - A slot on one side for receipt entry                                                                                                        │
│   - An exit slot on the opposite side                                                                                                           │
│   - A window between the rollers for the camera                                                                                                 │
│   - Mount points for camera, motor, and LEDs                                                                                                    │
│                                                                                                                                                 │
│ ---                                                                                                                                             │
│ Phase 2: Raspberry Pi Software Setup                                                                                                            │
│                                                                                                                                                 │
│ OS and Dependencies                                                                                                                             │
│                                                                                                                                                 │
│ # Flash Raspberry Pi OS (64-bit Lite) to SD card via Raspberry Pi Imager                                                                        │
│ # Boot, connect to WiFi, enable SSH and camera                                                                                                  │
│                                                                                                                                                 │
│ # System packages                                                                                                                               │
│ sudo apt update && sudo apt install -y \                                                                                                        │
│   python3-pip python3-venv \                                                                                                                    │
│   tesseract-ocr \                                                                                                                               │
│   libtesseract-dev \                                                                                                                            │
│   libatlas-base-dev \                                                                                                                           │
│   libcamera-apps                                                                                                                                │
│                                                                                                                                                 │
│ # Python virtual environment                                                                                                                    │
│ python3 -m venv ~/scanner-env                                                                                                                   │
│ source ~/scanner-env/bin/activate                                                                                                               │
│                                                                                                                                                 │
│ # Python packages                                                                                                                               │
│ pip install \                                                                                                                                   │
│   pytesseract \                                                                                                                                 │
│   Pillow \                                                                                                                                      │
│   picamera2 \       # Pi camera control                                                                                                         │
│   RPi.GPIO \        # motor GPIO control                                                                                                        │
│   requests \        # HTTP POST to bridge                                                                                                       │
│   numpy                                                                                                                                         │
│                                                                                                                                                 │
│ Camera Verification                                                                                                                             │
│                                                                                                                                                 │
│ # Test camera works                                                                                                                             │
│ libcamera-still -o test.jpg                                                                                                                     │
│ # Should produce a clear image                                                                                                                  │
│                                                                                                                                                 │
│ ---                                                                                                                                             │
│ Phase 3: Scanner Software (Python on Pi)                                                                                                        │
│                                                                                                                                                 │
│ Create a Python project receipt-scanner/ with these modules:                                                                                    │
│                                                                                                                                                 │
│ 3a. Motor Control (motor.py)                                                                                                                    │
│                                                                                                                                                 │
│ Controls the 28BYJ-48 stepper via ULN2003 to scroll the receipt past the camera.                                                                │
│                                                                                                                                                 │
│ Key behavior:                                                                                                                                   │
│ - feed_step(steps): advance receipt by N steps                                                                                                  │
│ - feed_receipt(): continuously feed while scanning                                                                                              │
│ - The motor should advance the receipt ~1 receipt-height per capture cycle                                                                      │
│   (receipt is ~7.5cm wide; camera FOV covers full width)                                                                                        │
│ - Step speed: ~5mm/second (slow enough for sharp capture)                                                                                       │
│                                                                                                                                                 │
│ GPIO pin mapping:                                                                                                                               │
│ - IN1 → GPIO 17                                                                                                                                 │
│ - IN2 → GPIO 18                                                                                                                                 │
│ - IN3 → GPIO 27                                                                                                                                 │
│ - IN4 → GPIO 22                                                                                                                                 │
│                                                                                                                                                 │
│ 3b. Image Capture (capture.py)                                                                                                                  │
│                                                                                                                                                 │
│ Capture frames from the Pi Camera as the receipt scrolls.                                                                                       │
│                                                                                                                                                 │
│ Key behavior:                                                                                                                                   │
│ - init_camera(): set up picamera2 with fixed focus, white balance tuned for                                                                     │
│   white paper + black text, resolution 1640x1232 or higher                                                                                      │
│ - capture_frame() → PIL Image: grab a single still frame                                                                                        │
│ - capture_receipt() → list[PIL Image]: coordinate with motor to capture                                                                         │
│   overlapping frames covering the full receipt length                                                                                           │
│ - Overlap each frame by ~20% to avoid missing lines at frame boundaries                                                                         │
│                                                                                                                                                 │
│ Scanning strategy:                                                                                                                              │
│ 1. User inserts receipt into slot                                                                                                               │
│ 2. A button press (or sensor trigger) starts the scan                                                                                           │
│ 3. Motor advances receipt in increments                                                                                                         │
│ 4. Camera captures a frame at each stop                                                                                                         │
│ 5. Repeat until receipt exits (detect blank frames = end of receipt)                                                                            │
│ 6. Return list of captured frames                                                                                                               │
│                                                                                                                                                 │
│ 3c. OCR Processing (ocr.py)                                                                                                                     │
│                                                                                                                                                 │
│ Run Tesseract on captured images to extract text.                                                                                               │
│                                                                                                                                                 │
│ Key behavior:                                                                                                                                   │
│ - preprocess_image(img) → img: convert to grayscale, threshold (adaptive                                                                        │
│   binary), deskew, sharpen. Thermal receipts are often low-contrast.                                                                            │
│ - ocr_image(img) → str: run pytesseract.image_to_string() with config                                                                           │
│   '--psm 6' (assume uniform block of text)                                                                                                      │
│ - ocr_receipt(frames) → str: process all frames, concatenate text,                                                                              │
│   deduplicate lines from overlapping regions                                                                                                    │
│                                                                                                                                                 │
│ Preprocessing pipeline (critical for accuracy):                                                                                                 │
│ 1. Convert to grayscale                                                                                                                         │
│ 2. Apply adaptive thresholding (cv2.adaptiveThreshold or Pillow equivalent)                                                                     │
│ 3. Deskew if rotated (detect angle via Hough lines or tesseract OSD)                                                                            │
│ 4. Scale up to 300 DPI equivalent if captured at lower resolution                                                                               │
│ 5. Denoise (median filter)                                                                                                                      │
│                                                                                                                                                 │
│ 3d. Receipt Parser (parser.py)                                                                                                                  │
│                                                                                                                                                 │
│ Parse raw OCR text into structured food items. This is the hardest part — receipt formats vary by store.                                        │
│                                                                                                                                                 │
│ Key behavior:                                                                                                                                   │
│ - parse_receipt(raw_text) → list[dict]: extract item names and prices                                                                           │
│ - Each dict: { "name": str, "price": float | None }                                                                                             │
│ - Filter out non-food lines (tax, totals, store name, address, phone,                                                                           │
│   barcodes, payment info, change, loyalty card, etc.)                                                                                           │
│                                                                                                                                                 │
│ Parsing strategy:                                                                                                                               │
│                                                                                                                                                 │
│ 1. Line-by-line analysis. Split OCR text into lines. Each line is a candidate item.                                                             │
│ 2. Filter known non-item patterns (regex):                                                                                                      │
│   - Lines matching TOTAL, SUBTOTAL, TAX, CHANGE, CASH, CREDIT, DEBIT, VISA, MASTERCARD                                                          │
│   - Lines that are just numbers (barcodes)                                                                                                      │
│   - Lines matching store header patterns (address, phone, date/time, store #)                                                                   │
│   - Lines starting with * or # (often metadata)                                                                                                 │
│   - Very short lines (< 3 chars)                                                                                                                │
│ 3. Extract item + price. Most receipt lines follow the pattern:                                                                                 │
│ ITEM NAME            $X.XX                                                                                                                      │
│ 3. Use regex: ^(.+?)\s{2,}\$?(\d+\.\d{2})\s*[A-Z]?$                                                                                             │
│ The trailing letter is often a tax code (T, F, N).                                                                                              │
│ 4. Normalize item names:                                                                                                                        │
│   - Strip leading/trailing whitespace                                                                                                           │
│   - Remove quantity prefixes like 2 x or 2@                                                                                                     │
│   - Title-case the name                                                                                                                         │
│   - Map common abbreviations: ORG → Organic, GRN → Green, BNL → Boneless, CHKN → Chicken                                                        │
│ 5. Match to known foods. Fuzzy-match each parsed name against the 96 items in expiry_dates.js to:                                               │
│   - Get the canonical food name                                                                                                                 │
│   - Auto-assign section (fridge/shelf/freezer) based on which has the longest shelf life                                                        │
│   - Auto-calculate expiration date using the shelf-life days                                                                                    │
│                                                                                                                                                 │
│ Use simple substring/Levenshtein matching. If no match found, default to section=fridge, expDate = buyDate + 7 days.                            │
│                                                                                                                                                 │
│ 3e. Pantree Integration (send.py)                                                                                                               │
│                                                                                                                                                 │
│ POST parsed items to the bridge server running alongside the Pantree app.                                                                       │
│                                                                                                                                                 │
│ import requests                                                                                                                                 │
│ import random                                                                                                                                   │
│ from datetime import date, timedelta                                                                                                            │
│                                                                                                                                                 │
│ BRIDGE_URL = "http://<pantree-host>:3001/api/add-foods"                                                                                         │
│                                                                                                                                                 │
│ def send_to_pantree(items):                                                                                                                     │
│     """                                                                                                                                         │
│     items: list of { name, section, exp_days }                                                                                                  │
│     """                                                                                                                                         │
│     today = date.today().isoformat()  # YYYY-MM-DD                                                                                              │
│     foods = []                                                                                                                                  │
│     for item in items:                                                                                                                          │
│         exp_date = (date.today() + timedelta(days=item["exp_days"])).isoformat()                                                                │
│         foods.append({                                                                                                                          │
│             "id": random.randint(10000, 99999),                                                                                                 │
│             "name": item["name"],                                                                                                               │
│             "icon": "",  # bridge server will resolve emoji                                                                                     │
│             "buyDate": today,                                                                                                                   │
│             "expDate": exp_date,                                                                                                                │
│             "section": item["section"]                                                                                                          │
│         })                                                                                                                                      │
│     response = requests.post(BRIDGE_URL, json={"foods": foods})                                                                                 │
│     return response.status_code == 200                                                                                                          │
│                                                                                                                                                 │
│ 3f. Main Entry Point (main.py)                                                                                                                  │
│                                                                                                                                                 │
│ Orchestrate the full scan pipeline.                                                                                                             │
│                                                                                                                                                 │
│ Flow:                                                                                                                                           │
│ 1. Wait for button press (GPIO input) or keyboard trigger                                                                                       │
│ 2. Start motor + capture frames                                                                                                                 │
│ 3. Run OCR on frames                                                                                                                            │
│ 4. Parse receipt text into items                                                                                                                │
│ 5. Display parsed items on terminal for confirmation                                                                                            │
│ 6. POST to bridge server                                                                                                                        │
│ 7. Print summary: "Added 12 items to Pantree"                                                                                                   │
│ 8. Return to waiting state                                                                                                                      │
│                                                                                                                                                 │
│ ---                                                                                                                                             │
│ Phase 4: Bridge Server (Node.js, runs on same machine as Pantree)                                                                               │
│                                                                                                                                                 │
│ The Pantree React app runs in a browser, so we can't write to its localStorage from an external Python script directly. The bridge server       │
│ solves this.                                                                                                                                    │
│                                                                                                                                                 │
│ Option A: Express + Puppeteer bridge (simplest)                                                                                                 │
│                                                                                                                                                 │
│ A small Node.js server that receives items via HTTP and injects them into the browser's localStorage.                                           │
│                                                                                                                                                 │
│ File: bridge-server/server.js                                                                                                                   │
│                                                                                                                                                 │
│ - Express server on port 3001                                                                                                                   │
│ - POST /api/add-foods  { foods: [...] }                                                                                                         │
│   1. Read current localStorage via Puppeteer (or keep in-memory cache)                                                                          │
│   2. Merge new foods into existing foods object                                                                                                 │
│   3. Write updated object to localStorage key "pantree-foods"                                                                                   │
│   4. Trigger the "pantree-storage" custom event so React picks it up                                                                            │
│   5. Return 200 with { added: count }                                                                                                           │
│                                                                                                                                                 │
│ Option B (simpler alternative): Shared file bridge                                                                                              │
│                                                                                                                                                 │
│ Instead of Puppeteer, modify firebase.js to read from a JSON file instead of localStorage, and have the Python scanner write to that file. But  │
│ this requires modifying the React app and adding file-watching logic. Option A is cleaner since it keeps the React app unchanged.               │
│                                                                                                                                                 │
│ Option C (recommended, simplest): Direct localStorage bridge via injected script                                                                │
│                                                                                                                                                 │
│ Add a tiny endpoint directly into the Pantree React app:                                                                                        │
│                                                                                                                                                 │
│ Modify src/utilities/firebase.js — add a global listener:                                                                                       │
│                                                                                                                                                 │
│ // Listen for messages from bridge                                                                                                              │
│ window.addEventListener('message', (event) => {                                                                                                 │
│   if (event.data?.type === 'pantree-add-foods') {                                                                                               │
│     const foods = readFoods();                                                                                                                  │
│     for (const food of event.data.foods) {                                                                                                      │
│       foods[food.id] = food;                                                                                                                    │
│     }                                                                                                                                           │
│     writeFoods(foods);  // writes to localStorage + dispatches event                                                                            │
│   }                                                                                                                                             │
│ });                                                                                                                                             │
│                                                                                                                                                 │
│ Then the bridge server just needs to POST to a small Express server that opens a WebSocket to the browser page, or — even simpler — add a small │
│  Express API directly to the React dev server using setupProxy.js:                                                                              │
│                                                                                                                                                 │
│ File: src/setupProxy.js (Create React App supports this natively)                                                                               │
│                                                                                                                                                 │
│ const { readFileSync, writeFileSync } = require('fs');                                                                                          │
│                                                                                                                                                 │
│ module.exports = function(app) {                                                                                                                │
│   app.post('/api/add-foods', require('express').json(), (req, res) => {                                                                         │
│     // Write a temp file that the React app polls, OR                                                                                           │
│     // use a simple in-memory approach:                                                                                                         │
│     const foods = req.body.foods;                                                                                                               │
│     // Store to a shared JSON file that firebase.js also reads                                                                                  │
│     const dataFile = path.join(__dirname, '..', 'pantree-data.json');                                                                           │
│     const existing = JSON.parse(readFileSync(dataFile, 'utf-8') || '{}');                                                                       │
│     for (const food of foods) {                                                                                                                 │
│       existing[food.id] = food;                                                                                                                 │
│     }                                                                                                                                           │
│     writeFileSync(dataFile, JSON.stringify(existing));                                                                                          │
│     res.json({ added: foods.length });                                                                                                          │
│   });                                                                                                                                           │
│ };                                                                                                                                              │
│                                                                                                                                                 │
│ But the cleanest approach for an MVP: Modify firebase.js to use a JSON file (read/write via a tiny Express API) instead of localStorage         │
│ directly. This way both the browser AND the scanner can read/write through the same API.                                                        │
│                                                                                                                                                 │
│ Recommended MVP bridge architecture:                                                                                                            │
│                                                                                                                                                 │
│ Create bridge-server/server.js — standalone Express server:                                                                                     │
│                                                                                                                                                 │
│ - Reads/writes pantree-data.json on disk                                                                                                        │
│ - GET  /api/foods → returns all foods                                                                                                           │
│ - POST /api/foods → adds foods (from scanner)                                                                                                   │
│ - DELETE /api/foods/:id → deletes a food                                                                                                        │
│                                                                                                                                                 │
│ Then modify firebase.js:                                                                                                                        │
│ - useData() fetches from GET /api/foods every 2 seconds (polling)                                                                               │
│ - setData() calls POST or DELETE on the API                                                                                                     │
│ - pushToFirebase() calls POST /api/foods                                                                                                        │
│ - deleteFromFirebase() calls DELETE /api/foods/:id                                                                                              │
│                                                                                                                                                 │
│ This makes the React app and the Pi scanner share the same data source with no browser automation needed.                                       │
│                                                                                                                                                 │
│ ---                                                                                                                                             │
│ Phase 5: Integration and End-to-End Testing                                                                                                     │
│                                                                                                                                                 │
│ Step-by-step verification                                                                                                                       │
│                                                                                                                                                 │
│ 1. Camera + motor standalone test:                                                                                                              │
│   - Run capture.py alone, feed a receipt manually                                                                                               │
│   - Verify captured images are sharp, well-lit, full-width                                                                                      │
│ 2. OCR standalone test:                                                                                                                         │
│   - Take a photo of a receipt with your phone, transfer to Pi                                                                                   │
│   - Run ocr.py on it, check text output quality                                                                                                 │
│   - Tune preprocessing (threshold values, DPI scaling) until item names are readable                                                            │
│ 3. Parser standalone test:                                                                                                                      │
│   - Feed sample OCR output (copy-paste real receipt text) into parser.py                                                                        │
│   - Verify it extracts correct item names and filters non-food lines                                                                            │
│   - Test with receipts from 2-3 different stores (Walmart, Kroger, Trader Joe's — formats differ)                                               │
│ 4. Bridge server test:                                                                                                                          │
│   - Start the bridge server                                                                                                                     │
│   - curl -X POST http://localhost:3001/api/foods -H 'Content-Type: application/json' -d                                                         │
│ '{"foods":[{"id":12345,"name":"Milk","icon":"","buyDate":"2026-03-01","expDate":"2026-03-08","section":"fridge"}]}'                             │
│   - Verify the item appears in the Pantree UI                                                                                                   │
│ 5. Full end-to-end test:                                                                                                                        │
│   - Insert a real grocery receipt into the device                                                                                               │
│   - Press the scan button                                                                                                                       │
│   - Watch items appear in the Pantree app within seconds                                                                                        │
│                                                                                                                                                 │
│ Common failure modes to watch for                                                                                                               │
│ ┌─────────────────────────┬────────────────────────────────────────────────────┬─────────────────────────────────────────────────────────────── │
│ ─┐                                                                                                                                              │
│ │          Issue          │                    Likely Cause                    │                              Fix                               │
│  │                                                                                                                                              │
│ ├─────────────────────────┼────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────── │
│ ─┤                                                                                                                                              │
│ │ OCR output is garbled   │ Poor lighting, camera too close/far, thermal paper │ Adjust LED angle, camera distance, increase contrast in        │
│  │                                                                                                                                              │
│ │                         │  faded                                             │ preprocessing                                                  │
│  │                                                                                                                                              │
│ ├─────────────────────────┼────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────── │
│ ─┤                                                                                                                                              │
│ │ Items missing from      │ Receipt format not handled                         │ Add store-specific regex patterns                              │
│  │                                                                                                                                              │
│ │ parse                   │                                                    │                                                                │
│  │                                                                                                                                              │
│ ├─────────────────────────┼────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────── │
│ ─┤                                                                                                                                              │
│ │ Duplicate items after   │ Overlapping frames not deduped                     │ Increase dedup threshold in ocr_receipt()                      │
│  │                                                                                                                                              │
│ │ scan                    │                                                    │                                                                │
│  │                                                                                                                                              │
│ ├─────────────────────────┼────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────── │
│ ─┤                                                                                                                                              │
│ │ Motor jams              │ Rollers too tight, paper crumpled                  │ Increase roller gap slightly, add paper guide rails            │
│  │                                                                                                                                              │
│ ├─────────────────────────┼────────────────────────────────────────────────────┼─────────────────────────────────────────────────────────────── │
│ ─┤                                                                                                                                              │
│ │ Items don't appear in   │ Bridge server not running, wrong URL               │ Check bridge server logs, verify port and endpoint             │
│  │                                                                                                                                              │
│ │ app                     │                                                    │                                                                │
│  │                                                                                                                                              │
│ └─────────────────────────┴────────────────────────────────────────────────────┴─────────────────────────────────────────────────────────────── │
│ ─┘                                                                                                                                              │
│ ---                                                                                                                                             │
│ File Summary                                                                                                                                    │
│                                                                                                                                                 │
│ New files to create                                                                                                                             │
│ ┌──────────────────────────────────┬──────────────────────────────────────────┐                                                                 │
│ │               File               │                 Purpose                  │                                                                 │
│ ├──────────────────────────────────┼──────────────────────────────────────────┤                                                                 │
│ │ receipt-scanner/main.py          │ Entry point — orchestrates scan pipeline │                                                                 │
│ ├──────────────────────────────────┼──────────────────────────────────────────┤                                                                 │
│ │ receipt-scanner/motor.py         │ Stepper motor control via GPIO           │                                                                 │
│ ├──────────────────────────────────┼──────────────────────────────────────────┤                                                                 │
│ │ receipt-scanner/capture.py       │ Pi Camera frame capture                  │                                                                 │
│ ├──────────────────────────────────┼──────────────────────────────────────────┤                                                                 │
│ │ receipt-scanner/ocr.py           │ Tesseract OCR + image preprocessing      │                                                                 │
│ ├──────────────────────────────────┼──────────────────────────────────────────┤                                                                 │
│ │ receipt-scanner/parser.py        │ Receipt text → structured food items     │                                                                 │
│ ├──────────────────────────────────┼──────────────────────────────────────────┤                                                                 │
│ │ receipt-scanner/send.py          │ HTTP POST items to bridge server         │                                                                 │
│ ├──────────────────────────────────┼──────────────────────────────────────────┤                                                                 │
│ │ receipt-scanner/requirements.txt │ Python dependencies                      │                                                                 │
│ ├──────────────────────────────────┼──────────────────────────────────────────┤                                                                 │
│ │ bridge-server/server.js          │ Express API for shared food data         │                                                                 │
│ ├──────────────────────────────────┼──────────────────────────────────────────┤                                                                 │
│ │ bridge-server/package.json       │ Node.js dependencies                     │                                                                 │
│ └──────────────────────────────────┴──────────────────────────────────────────┘                                                                 │
│ Files to modify                                                                                                                                 │
│ ┌───────────────────────────┬────────────────────────────────────────────────────────────────────────────────────────────┐                      │
│ │           File            │                                           Change                                           │                      │
│ ├───────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────┤                      │
│ │ src/utilities/firebase.js │ Switch from localStorage to bridge API (fetch/POST) so both browser and scanner share data │                      │
│ └───────────────────────────┴────────────────────────────────────────────────────────────────────────────────────────────┘                      │
│ Files unchanged                                                                                                                                 │
│                                                                                                                                                 │
│ All other Pantree source files (App.js, food.js, form.js, select.js, etc.) remain unchanged.                                                    │
│                                                                                                                                                 │
│ ---                                                                                                                                             │
│ Stretch Goals (post-MVP)                                                                                                                        │
│                                                                                                                                                 │
│ - IR/optical sensor at the intake slot to auto-detect receipt insertion and start scanning without a button press                               │
│ - On-screen review UI — show parsed items in the Pantree app with checkboxes before committing, so user can deselect non-food items             │
│ - Store-specific parsers — dedicated parsing logic for common stores (Walmart, Costco, Kroger, etc.) since their receipt formats are            │
│ predictable                                                                                                                                     │
│ - Barcode scanning — some receipts print barcodes next to items; a barcode DB lookup could improve accuracy over OCR                            │
│ - Multi-receipt stitching — handle long receipts that need multiple passes                                                                      │
│ - Thermal printer output — print a summary of what was added (using a small thermal printer module on the Pi)