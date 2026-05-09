# Pantree iOS

Native SwiftUI proof-of-concept for Pantree food intelligence. The app is designed to be opened in Xcode and deployed to a physical iPhone, including iPhone 13 Pro.

## What works locally

- Inventory dashboard with health balance, expiration risk, shopping suggestions, meal ideas, and ML-readiness notes.
- Local receipt import from pasted/sample OCR text.
- Camera-style receipt capture with a bottom-center shutter, bottom-left photo library picker, and local Vision OCR.
- Food photo prediction UI with a local predictor abstraction and camera picker.
- Local JSON persistence in the app sandbox.
- Unit, integration, and UI tests.

## Privacy defaults

- No external APIs are called.
- Receipt text, food inventory, events, and photo predictions stay on-device.
- The current photo predictor uses deterministic local labels; a bundled Core ML model can replace it later without changing the UI.

## Build in Xcode

1. Open `Pantree.xcodeproj` in Xcode.
2. Select the `Pantree` scheme.
3. For a physical iPhone, select your iPhone 13 Pro as the run destination.
4. In Signing & Capabilities, select your Apple Developer Team if Xcode asks for signing.
5. Run the app.

## Command-line validation

```sh
xcodebuild -list -project Pantree.xcodeproj
xcodebuild build -project Pantree.xcodeproj -scheme Pantree -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'
xcodebuild test -project Pantree.xcodeproj -scheme Pantree -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'
```
