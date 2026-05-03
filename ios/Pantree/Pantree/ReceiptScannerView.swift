import PhotosUI
import SwiftUI
#if canImport(Vision)
import Vision
#endif
#if canImport(VisionKit)
import VisionKit
#endif

struct ReceiptScannerView: View {
    @EnvironmentObject private var store: LocalFoodStore
    @State private var receiptText = ""
    @State private var parseResult: ReceiptParseResult?
    @State private var selectedDetectedItemIDs: Set<UUID> = []
    @State private var importedItemIDs: Set<UUID> = []
    @State private var errorMessage: String?
    @State private var photoImportMessage: String?
    @State private var showingCameraScanner = false
    @State private var selectedReceiptPhoto: PhotosPickerItem?
    @State private var isRecognizingReceiptPhoto = false
    @FocusState private var isReceiptTextFocused: Bool

    private let parser = ReceiptParser()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Scan a receipt with the camera on iPhone, or paste OCR text. The POC parses text locally and predicts storage/expiration without external APIs.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button("Use Sample Receipt") {
                            isReceiptTextFocused = false
                            receiptText = SampleData.sampleReceipt
                            detectReceiptItems(from: SampleData.sampleReceipt, showErrorForEmpty: true)
                            photoImportMessage = nil
                        }
                        .buttonStyle(.bordered)

                        cameraButton
                    }

                    PhotosPicker(
                        selection: Binding(
                            get: { selectedReceiptPhoto },
                            set: { newItem in
                                selectedReceiptPhoto = newItem
                                if let newItem {
                                    recognizeReceiptPhoto(newItem)
                                }
                            }
                        ),
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label(isRecognizingReceiptPhoto ? "Reading Receipt Photo..." : "Choose Receipt Photo", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRecognizingReceiptPhoto)
                    .accessibilityIdentifier("ChooseReceiptPhotoButton")

                    TextEditor(text: $receiptText)
                        .focused($isReceiptTextFocused)
                        .frame(minHeight: 190)
                        .padding(8)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .accessibilityIdentifier("ReceiptTextEditor")

                    Button("Refresh Detected Items") {
                        detectReceiptItems(showErrorForEmpty: true)
                    }
                    .buttonStyle(.bordered)
                    .disabled(receiptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("DetectReceiptItemsButton")

                    if let parseResult {
                        ParsedReceiptPanel(
                            result: parseResult,
                            selectedItemIDs: $selectedDetectedItemIDs,
                            importedItemIDs: importedItemIDs
                        )

                        Button(addSelectedButtonTitle(for: parseResult)) {
                            addSelectedItemsToInventory()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedUnimportedItems(from: parseResult).isEmpty)
                        .accessibilityIdentifier("AddSelectedReceiptItemsButton")
                    }

                    if let photoImportMessage {
                        Label(photoImportMessage, systemImage: "text.viewfinder")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Receipt")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isReceiptTextFocused = false
                    }
                    .accessibilityIdentifier("DismissReceiptKeyboardButton")
                }
            }
            .sheet(isPresented: $showingCameraScanner) {
                cameraScannerSheet
            }
            .onChange(of: receiptText) { _, newText in
                detectReceiptItems(from: newText)
            }
        }
    }

    @ViewBuilder
    private var cameraButton: some View {
        #if canImport(VisionKit)
        if #available(iOS 16.0, *), DataScannerViewController.isSupported {
            Button("Scan With Camera") {
                isReceiptTextFocused = false
                showingCameraScanner = true
            }
            .buttonStyle(.borderedProminent)
        } else {
            Button("Camera OCR unavailable") {}
                .buttonStyle(.bordered)
                .disabled(true)
        }
        #else
        Button("Camera OCR unavailable") {}
            .buttonStyle(.bordered)
            .disabled(true)
        #endif
    }

    @ViewBuilder
    private var cameraScannerSheet: some View {
        #if canImport(VisionKit)
        if #available(iOS 16.0, *) {
            ReceiptDataScannerView(recognizedText: $receiptText)
        } else {
            Text("Camera OCR requires iOS 16 or later.").padding()
        }
        #else
        Text("VisionKit is unavailable on this platform.").padding()
        #endif
    }

    private func detectReceiptItems(from text: String? = nil, showErrorForEmpty: Bool = false) {
        let sourceText = text ?? receiptText
        let trimmed = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            parseResult = nil
            selectedDetectedItemIDs = []
            importedItemIDs = []
            if showErrorForEmpty {
                errorMessage = "Paste or scan receipt text first."
            }
            return
        }

        let result = parser.parse(trimmed)
        parseResult = result
        selectedDetectedItemIDs = Set(result.items.map(\.id))
        importedItemIDs = []

        if result.items.isEmpty, showErrorForEmpty {
            errorMessage = "No grocery items were found in this receipt text."
        } else {
            errorMessage = nil
        }
    }

    private func addSelectedItemsToInventory() {
        isReceiptTextFocused = false
        guard let parseResult else { return }

        let selectedItems = selectedUnimportedItems(from: parseResult)
        guard !selectedItems.isEmpty else {
            errorMessage = "Select at least one detected item to add."
            return
        }

        do {
            let selectedResult = ReceiptParseResult(receiptId: parseResult.receiptId, items: selectedItems, ignoredLines: parseResult.ignoredLines)
            let imported = try store.importReceipt(selectedResult)
            importedItemIDs.formUnion(imported.map(\.id))
            photoImportMessage = "Added \(imported.count) selected item\(imported.count == 1 ? "" : "s") to inventory."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func selectedUnimportedItems(from result: ReceiptParseResult) -> [FoodItem] {
        result.items.filter { selectedDetectedItemIDs.contains($0.id) && !importedItemIDs.contains($0.id) }
    }

    private func addSelectedButtonTitle(for result: ReceiptParseResult) -> String {
        let count = selectedUnimportedItems(from: result).count
        return "Add \(count) Selected Item\(count == 1 ? "" : "s") to Inventory"
    }

    private func recognizeReceiptPhoto(_ item: PhotosPickerItem) {
        isReceiptTextFocused = false
        Task {
            await MainActor.run {
                isRecognizingReceiptPhoto = true
                errorMessage = nil
                photoImportMessage = nil
            }

            do {
                guard let imageData = try await item.loadTransferable(type: Data.self) else {
                    throw ReceiptImageTextRecognizerError.missingImageData
                }
                let recognizedText = try await ReceiptImageTextRecognizer().recognizeText(from: imageData)
                await MainActor.run {
                    selectedReceiptPhoto = nil
                    isRecognizingReceiptPhoto = false
                    guard !recognizedText.isEmpty else {
                        errorMessage = "No readable receipt text was found in that photo."
                        return
                    }
                    receiptText = recognizedText
                    detectReceiptItems(from: recognizedText)
                    photoImportMessage = "Loaded receipt text from photo locally. Review detected items before adding."
                }
            } catch {
                await MainActor.run {
                    selectedReceiptPhoto = nil
                    isRecognizingReceiptPhoto = false
                    errorMessage = "Could not read receipt photo: \(error.localizedDescription)"
                }
            }
        }
    }
}

enum ReceiptImageTextRecognizerError: LocalizedError, Equatable {
    case missingImageData
    case visionUnavailable

    var errorDescription: String? {
        switch self {
        case .missingImageData:
            return "The selected photo could not be loaded."
        case .visionUnavailable:
            return "On-device text recognition is unavailable on this platform."
        }
    }
}

struct ReceiptImageTextRecognizer: Sendable {
    func recognizeText(from imageData: Data) async throws -> String {
        #if canImport(Vision)
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = Self.normalizedOCRText(
                    observations
                        .compactMap { $0.topCandidates(1).first?.string }
                        .joined(separator: "\n")
                )
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let handler = VNImageRequestHandler(data: imageData, options: [:])
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        #else
        throw ReceiptImageTextRecognizerError.visionUnavailable
        #endif
    }

    static func normalizedOCRText(_ text: String) -> String {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

struct ParsedReceiptPanel: View {
    var result: ReceiptParseResult
    @Binding var selectedItemIDs: Set<UUID>
    var importedItemIDs: Set<UUID>

    var body: some View {
        Panel(title: "Parsed locally") {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(result.items.count) food item\(result.items.count == 1 ? "" : "s") detected")
                    .font(.headline)
                Text("Uncheck anything that is not food before adding to inventory.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(result.items) { item in
                    Button {
                        toggleSelection(for: item)
                    } label: {
                        HStack {
                            Image(systemName: selectedItemIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedItemIDs.contains(item.id) ? .green : .secondary)
                            FoodIconBadge(item: item)
                            VStack(alignment: .leading) {
                                Text(item.name)
                                Text("\(item.category.title) · expires \(item.expDate, format: .dateTime.month().day())")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if importedItemIDs.contains(item.id) {
                                Image(systemName: "tray.and.arrow.down.fill").foregroundStyle(.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(importedItemIDs.contains(item.id))
                    .accessibilityIdentifier("DetectedReceiptItem-\(item.canonicalName)")
                }
                if !result.ignoredLines.isEmpty {
                    Text("Ignored \(result.ignoredLines.count) receipt/admin line\(result.ignoredLines.count == 1 ? "" : "s").")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier("ParsedReceiptPanel")
    }

    private func toggleSelection(for item: FoodItem) {
        if selectedItemIDs.contains(item.id) {
            selectedItemIDs.remove(item.id)
        } else {
            selectedItemIDs.insert(item.id)
        }
    }
}
