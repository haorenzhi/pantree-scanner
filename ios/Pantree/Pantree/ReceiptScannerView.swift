import SwiftUI
#if canImport(VisionKit)
import VisionKit
#endif

struct ReceiptScannerView: View {
    @EnvironmentObject private var store: LocalFoodStore
    @State private var receiptText = ""
    @State private var parseResult: ReceiptParseResult?
    @State private var importedNames: [String] = []
    @State private var errorMessage: String?
    @State private var showingCameraScanner = false

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
                            receiptText = SampleData.sampleReceipt
                            parseResult = nil
                            importedNames = []
                        }
                        .buttonStyle(.bordered)

                        cameraButton
                    }

                    TextEditor(text: $receiptText)
                        .frame(minHeight: 190)
                        .padding(8)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .accessibilityIdentifier("ReceiptTextEditor")

                    Button("Import Receipt") { importReceipt() }
                        .buttonStyle(.borderedProminent)
                        .disabled(receiptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("ImportReceiptButton")

                    if let parseResult {
                        ParsedReceiptPanel(result: parseResult, importedNames: importedNames)
                    }

                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("Receipt")
            .sheet(isPresented: $showingCameraScanner) {
                cameraScannerSheet
            }
        }
    }

    @ViewBuilder
    private var cameraButton: some View {
        #if canImport(VisionKit)
        if #available(iOS 16.0, *), DataScannerViewController.isSupported {
            Button("Scan With Camera") {
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

    private func importReceipt() {
        let result = parser.parse(receiptText)
        parseResult = result
        guard !result.items.isEmpty else {
            errorMessage = "No grocery items were found in this receipt text."
            return
        }
        do {
            let imported = try store.importReceipt(result)
            importedNames = imported.map(\.name)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ParsedReceiptPanel: View {
    var result: ReceiptParseResult
    var importedNames: [String]

    var body: some View {
        Panel(title: "Parsed locally") {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(result.items.count) food item\(result.items.count == 1 ? "" : "s") detected")
                    .font(.headline)
                ForEach(result.items) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.name)
                            Text("\(item.category.title) · expires \(item.expDate, format: .dateTime.month().day())")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if importedNames.contains(item.name) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        }
                    }
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
}
