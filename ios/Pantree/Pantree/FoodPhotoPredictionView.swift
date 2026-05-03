import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct FoodPhotoPredictionView: View {
    @EnvironmentObject private var store: LocalFoodStore
    @State private var predictions: [FoodPrediction] = []
    @State private var message: String?
    @State private var showingCamera = false

    private let predictor = LocalFoodPhotoPredictor()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Take or simulate a food photo. This POC uses a local predictor abstraction so a bundled Core ML model can replace the sample labels later.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button("Use Sample Meal Photo") {
                            predictions = predictor.predict(from: predictor.sampleMealLabels(), inventory: store.items)
                            message = "Predicted from local sample labels."
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("SamplePhotoButton")

                        cameraButton
                    }

                    if let message {
                        Label(message, systemImage: "checkmark.shield.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    PredictionPanel(predictions: predictions)

                    Panel(title: "Why this is privacy-safe") {
                        Text("Images are handled on-device. The current demo emits deterministic local labels; production can add a Core ML food classifier without sending photos to a server.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Photo")
            .sheet(isPresented: $showingCamera) {
                #if canImport(UIKit)
                CameraImagePicker { image in
                    Task { await predictCapturedImage(image) }
                }
                #else
                Text("Camera is unavailable on this platform.").padding()
                #endif
            }
        }
    }

    #if canImport(UIKit)
    @MainActor
    private func predictCapturedImage(_ image: UIImage) async {
        let labels = await LocalHeuristicImageLabeler().labels(for: image)
        predictions = predictor.predict(from: labels, inventory: store.items)
        message = "Predicted from captured image using local placeholder labels."
    }
    #endif

    @ViewBuilder
    private var cameraButton: some View {
        #if canImport(UIKit)
        Button("Take Photo") {
            showingCamera = true
        }
        .buttonStyle(.bordered)
        #else
        Button("Take Photo") {}
            .buttonStyle(.bordered)
            .disabled(true)
        #endif
    }
}

struct PredictionPanel: View {
    @EnvironmentObject private var store: LocalFoodStore
    var predictions: [FoodPrediction]

    var body: some View {
        Panel(title: "Predictions") {
            if predictions.isEmpty {
                Text("No predictions yet. Use the sample photo or take a picture.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(predictions) { prediction in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            FoodIconBadge(name: prediction.foodName)
                            Text(prediction.foodName).font(.headline)
                            Spacer()
                            Text("\((prediction.confidence * 100).rounded(toPlaces: 0), specifier: "%.0f")%")
                                .font(.caption.bold())
                        }
                        Text(prediction.reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let itemId = prediction.inventoryItemId {
                            Button("Log as eaten") {
                                _ = try? store.consume(itemId: itemId, amount: 1, note: "Logged from photo prediction")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
        }
        .accessibilityIdentifier("PredictionPanel")
    }
}
