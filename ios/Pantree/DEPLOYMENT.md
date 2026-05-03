# Pantree iOS Deployment Guide

This app is a native SwiftUI app, not a web wrapper. It is designed to run locally on iPhone with no external APIs.

## Reused work from the existing project

| Existing project area | Native iOS equivalent | Notes |
| --- | --- | --- |
| `bridge-server/phase2/static-data.js` | `Pantree/LocalFoodKnowledge.swift` | Local food profiles, aliases, categories, storage defaults, shelf-life rules, nutrition hints were ported to Swift. |
| `bridge-server/phase2/intelligence.js` | `Pantree/FoodIntelligenceEngine.swift` | Health balance, expiry risk, shopping suggestions, meal ideas, value-at-risk were reimplemented as testable Swift logic. |
| `bridge-server/phase2/data-store.js` and `event-service.js` | `Pantree/LocalFoodStore.swift` | Local JSON persistence and food events now live in the iOS sandbox. |
| `receipt-scanner/parser.py` and `bridge-server/receipt-parser.js` concepts | `Pantree/ReceiptParser.swift` | Receipt text parsing is local and deterministic for the POC. |
| `src/components/Phase2Dashboard.js` | `Pantree/ContentView.swift`, `InventoryView.swift` | React dashboard concepts are now native SwiftUI views. |
| Phase 2 privacy rules | All iOS modules | No external APIs; camera/photo/receipt data stays on-device. |

Not directly reused: React components, Node Express routes, Python Pi GPIO/camera/motor code. Those remain useful for the Pi station and web bridge, but iOS requires Swift/SwiftUI and Apple camera/Vision frameworks.

## Step 1: Check device visibility

Run the VS Code task **iOS: List Devices and Simulators**.

A physical iPhone should show as `available`. If it shows `unavailable`:

1. Connect the iPhone with USB-C/Lightning.
2. Unlock the iPhone.
3. Tap **Trust This Computer** if prompted.
4. On iPhone: Settings → Privacy & Security → Developer Mode → On, then restart if requested.
5. In Xcode: Window → Devices and Simulators → select the iPhone and wait until pairing finishes.

## Step 2: Validate on simulator

Run these VS Code tasks:

1. **iOS: Build Simulator**
2. **iOS: Test Simulator**

The current verified simulator destination is:

```sh
platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2
```

It is OK that this is not iPhone 13 Pro; simulator validation checks the app logic and UI. Real camera testing should happen on the physical phone.

## Step 3: Open in Xcode for iPhone deployment

Run the VS Code task **iOS: Open Pantree in Xcode**.

In Xcode:

1. Select scheme **Pantree**.
2. Select your connected iPhone as the run destination.
3. Open target **Pantree** → **Signing & Capabilities**.
4. Select your Apple Developer Team.
5. Keep bundle identifier as `com.pantree.scanner`, or change it if Xcode says it is already taken.
6. Press **Run**.

## Step 4: First-run permissions on iPhone

The app may ask for camera/photo permission. Allow it for receipt scanning and food-photo prediction.

The app currently uses local deterministic prediction labels until a bundled Core ML model is added. It does not upload images.

## Step 5: Test real iPhone flows

On the device, verify:

1. Dashboard shows local inventory and privacy banner.
2. Inventory tab shows sample foods.
3. Receipt tab → **Use Sample Receipt** → **Import Receipt**.
4. Receipt tab → **Scan With Camera** if VisionKit is available.
5. Photo tab → **Take Photo** and **Use Sample Meal Photo**.
6. Use **Ate** or **Discard** and confirm the dashboard updates.

## VS Code task summary

- **iOS: Open Pantree in Xcode** — best path for physical iPhone deployment.
- **iOS: List Devices and Simulators** — checks if the phone is paired/available.
- **iOS: Build Simulator** — builds app locally.
- **iOS: Test Simulator** — runs unit, integration, and UI tests.
- **iOS: Build Generic Device (requires signing)** — checks device build/signing from command line after your Apple Team is configured.
