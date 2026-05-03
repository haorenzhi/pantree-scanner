# Phase 2 Plan — Privacy-First Food Intelligence POC

## Product Positioning

Pantree should evolve from an expiration-date tracker into a privacy-first food intelligence app that understands the full flow from receipt to fridge to plate:

> Pantree helps households know what they bought, what is left, what should be eaten first, what habits are forming, and when to restock — while keeping personal food data local.

The Raspberry Pi scanner remains an optional kitchen capture station. The iOS app becomes the primary daily interface for receipt capture, barcode/photo entry, meal logging, reminders, and quick inventory actions.

## Non-Negotiable Privacy Principles

1. **Local-first by default.** Personal inventory, receipts, meal events, prices, and consumption history stay on the user's device or local bridge server during the POC.
2. **No external APIs in Phase 2 POC.** Nutrition, category, meal, and shelf-life intelligence use local static data and cache files only.
3. **No cloud sync until explicitly designed.** Future sync must be opt-in, encrypted, and household-scoped.
4. **AI as suggestion, not truth.** Any recognition, nutrition, or expiration result must be presented as an estimate that the user can confirm or edit.
5. **Modular features.** Each feature should be removable without breaking the base pantry inventory.

## Current Foundation

Current data already includes or can produce:

- Food item name
- Buy date
- Predicted expiration date
- Storage section: `fridge`, `freezer`, `shelf`, `used`
- Price from receipt parsing in the bridge scan path
- Emoji and default expiry mapping from local food DB
- Receipt photo OCR through the bridge server
- Manual add/edit/delete in the React app

## Phase 2 Data Model Direction

Phase 2 should treat the pantry as a local event ledger instead of only a current-state list.

### `FoodItem`

Suggested fields:

- `id`
- `name`
- `canonicalName`
- `category`
- `section`
- `buyDate`
- `expDate`
- `openedAt`
- `price`
- `quantity`
- `unit`
- `remainingQty`
- `source`: `receipt`, `manual`, `barcode`, `meal-photo`, `pi-scanner`
- `confidence`
- `nutrition`
- `barcode`
- `store`
- `receiptId`

### `FoodEvent`

Suggested local-only event types:

- `purchase`
- `consume`
- `discard`
- `open`
- `move`
- `restock`
- `edit`

Each event should include:

- `id`
- `type`
- `foodId`
- `foodName`
- `amount`
- `unit`
- `reason`
- `createdAt`
- `source`
- `note`

## Incremental POC Features

Each feature below includes a realism and benefit analysis before implementation.

### 1. Local Phase 2 Intelligence Cache

**Analysis:** Realistic and low-risk. We can avoid external APIs by using a local static food intelligence table for common foods. This gives immediate nutrition/category/waste-risk demos without leaking data.

**Benefit:** Users get healthier and more convenient guidance immediately: produce/protein balance, local meal ideas, and rough nutrition context.

**Implementation:**

- Add local static food profiles.
- Include category, default unit, default quantity, serving calories, macros, and aliases.
- Keep the module isolated from external services.

### 2. Local Food Event Ledger

**Analysis:** Realistic and essential. Current pantry state cannot explain consumption, waste, or restock behavior. A local event ledger gives us future analytics without changing every UI flow at once.

**Benefit:** Users can quickly mark food as eaten or discarded and start seeing usage and waste patterns.

**Implementation:**

- Add local `pantree-events.json` runtime storage.
- Add isolated event service and routes.
- Keep user event data ignored by Git.

### 3. Expiry and Waste Risk Summary

**Analysis:** Realistic because we already know buy dates, expiration dates, price, and section. The first version can use transparent rules instead of ML.

**Benefit:** Helps users eat food before it spoils and saves money by surfacing value at risk.

**Implementation:**

- Compute days until expiration.
- Rank active items by expiry risk.
- Estimate value at risk from `price * remainingShare` when price exists.

### 4. Smart Shopping Suggestions

**Analysis:** Realistic for a POC if scoped to local history and current inventory. We should not claim perfect prediction yet.

**Benefit:** Makes grocery planning easier and reduces forgotten staples.

**Implementation:**

- Suggest low/empty items.
- Suggest recently consumed or discarded items that are no longer active.
- Use local event history only.

### 5. Inventory Health Balance

**Analysis:** Realistic as a grocery-balance signal, not a medical nutrition score. It should analyze what is available at home, not claim exact daily intake.

**Benefit:** Encourages healthier household food availability, such as more produce or protein diversity.

**Implementation:**

- Group active inventory by produce, protein, dairy, grains, pantry staples, and treats.
- Produce simple balance messages.
- Clearly label the result as an estimate.

### 6. Local Meal Ideas

**Analysis:** Realistic with static recipes and ingredient matching. It is useful even without external recipe APIs.

**Benefit:** Helps users decide what to cook, especially with expiring ingredients.

**Implementation:**

- Add a local recipe list.
- Match recipe ingredients against inventory.
- Prioritize recipes that use expiring food and require few missing ingredients.

### 7. iOS Real-Time ML Exploration

**Analysis:** Useful but should be planned, not fully implemented in this web POC. The best candidates are lightweight, on-device, privacy-preserving models.

**High-value ML areas:**

1. **Meal photo recognition:** classify common foods and match them against current inventory.
2. **Portion estimation:** estimate count or rough remaining percentage for simple foods.
3. **Receipt line cleanup:** improve OCR item normalization and canonical food matching.
4. **Restock prediction:** learn personal consumption intervals from local events.
5. **Waste-risk prediction:** learn which foods a household often wastes before expiration.

**Best iOS deployment target:** Core ML models running on-device. Start with small image classifiers or text classifiers, quantized if needed, with user confirmation in the loop.

**Data to collect locally:**

- User-confirmed meal photo labels.
- Before/after remaining quantities.
- Receipt OCR raw line -> corrected item name pairs.
- Consume/discard/restock timestamps.
- Expired-but-eaten vs discarded outcomes.

**Low-latency guidance:**

- Run image classification at low resolution.
- Use current inventory as a candidate filter.
- Return top 3 suggestions only.
- Avoid server inference for private food photos in the default mode.

## Implementation Strategy

1. Add isolated Phase 2 backend modules under `bridge-server/phase2/`.
2. Add isolated React UI under `src/components/Phase2Dashboard.js` and CSS.
3. Mount routes under `/api/phase2` so existing `/api/foods` remains stable.
4. Keep all POC intelligence local and static.
5. Keep runtime user data ignored by Git.
6. Validate with local server and production build.

## Future iOS Architecture

The iOS app should be fully usable without Raspberry Pi hardware:

- Local database: Core Data or SQLite.
- Local ML: Core ML + Vision.
- Camera: VisionKit text/barcode scanning and custom food photo capture.
- Sync: optional encrypted household sync later.
- Pi: optional local producer of receipt scans and kitchen events.

## Definition of Done for Phase 2 POC

- A user can keep using the current pantry app.
- The app shows local-only Phase 2 insights.
- A user can mark food as consumed or discarded from the Phase 2 dashboard.
- The bridge exposes isolated `/api/phase2` endpoints.
- No external API calls are required.
- Runtime food event data stays local and is not committed.
