import SwiftUI
#if canImport(VisionKit)
import VisionKit

@available(iOS 16.0, *)
struct ReceiptDataScannerView: UIViewControllerRepresentable {
    @Binding var recognizedText: String
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        try? controller.startScanning()
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(recognizedText: $recognizedText)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        @Binding var recognizedText: String

        init(recognizedText: Binding<String>) {
            _recognizedText = recognizedText
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            sync(allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            sync(allItems)
        }

        private func sync(_ items: [RecognizedItem]) {
            let lines = items.compactMap { item -> String? in
                if case let .text(text) = item {
                    return text.transcript
                }
                return nil
            }
            let merged = lines.joined(separator: "\n")
            guard !merged.isEmpty else { return }
            recognizedText = merged
        }
    }
}
#endif
