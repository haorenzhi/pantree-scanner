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
    private let recommendedDailyCalories = 2_000.0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Take or simulate a meal photo. Pantree estimates calories locally, records meal calories, and compares today's total with a default daily recommendation.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    CalorieProgressPanel(
                        totalCalories: store.dailyCalories(),
                        recommendedCalories: recommendedDailyCalories,
                        mealRecords: todaysMealRecords
                    )

                    HStack {
                        Button("Use Sample Meal Photo") {
                            predictions = predictor.predict(from: predictor.sampleMealLabels(), inventory: store.items)
                            message = "Predicted foods and calories from local sample labels."
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

                    PredictionPanel(predictions: predictions) {
                        recordCurrentMeal()
                    }

                    Panel(title: "Why this is privacy-safe") {
                        Text("Images and meal records are handled on-device. The current demo emits deterministic local labels and calorie estimates; production can add a bundled Core ML food classifier without sending photos to a server.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Diet")
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
        message = "Predicted foods and calories from captured image using local placeholder labels."
    }
    #endif

    private var todaysMealRecords: [MealCalorieRecord] {
        let calendar = Calendar.current
        return store.mealRecords
            .filter { calendar.isDateInToday($0.createdAt) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func recordCurrentMeal() {
        do {
            let record = try store.recordMealCalories(from: predictions)
            message = "Recorded meal: \(record.totalCalories.cleanText) kcal."
        } catch {
            message = "Could not record meal calories: \(error.localizedDescription)"
        }
    }

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

struct CalorieProgressPanel: View {
    var totalCalories: Double
    var recommendedCalories: Double
    var mealRecords: [MealCalorieRecord]

    private var progress: Double {
        guard recommendedCalories > 0 else { return 0 }
        return min(1, totalCalories / recommendedCalories)
    }

    private var remainingCalories: Double {
        recommendedCalories - totalCalories
    }

    var body: some View {
        Panel(title: "Daily calories") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(totalCalories.cleanText)")
                        .font(.largeTitle.bold())
                    Text("/ \(recommendedCalories.cleanText) kcal")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: progress)
                    .tint(remainingCalories >= 0 ? .green : .orange)
                    .accessibilityIdentifier("DailyCaloriesProgress")
                Text(remainingCalories >= 0
                     ? "\(remainingCalories.cleanText) kcal remaining against the default recommendation."
                     : "\(abs(remainingCalories).cleanText) kcal over the default recommendation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if mealRecords.isEmpty {
                    Text("No meals recorded today yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Divider()
                    ForEach(mealRecords.prefix(5)) { record in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(record.createdAt, format: .dateTime.hour().minute())
                                    .font(.caption.bold())
                                Spacer()
                                Text("\(record.totalCalories.cleanText) kcal")
                                    .font(.caption.bold())
                            }
                            Text(record.entries.map(\.foodName).joined(separator: ", "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityIdentifier("MealCalorieRecord")
                    }
                }
            }
        }
        .accessibilityIdentifier("DailyCaloriesPanel")
    }
}

struct PredictionPanel: View {
    @EnvironmentObject private var store: LocalFoodStore
    var predictions: [FoodPrediction]
    var onRecordMeal: () -> Void

    private var estimatedMealCalories: Double {
        predictions.map(\.estimatedCalories).reduce(0, +).rounded(toPlaces: 0)
    }

    var body: some View {
        Panel(title: "Meal predictions") {
            if predictions.isEmpty {
                Text("No predictions yet. Use the sample photo or take a picture.")
                    .foregroundStyle(.secondary)
            } else {
                HStack {
                    Text("Estimated meal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(estimatedMealCalories.cleanText) kcal")
                        .font(.headline)
                }
                Button("Record Meal Calories") {
                    onRecordMeal()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Record Meal Calories")
                .accessibilityIdentifier("RecordMealCaloriesButton")

                ForEach(predictions) { prediction in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            FoodIconBadge(name: prediction.foodName)
                            Text(prediction.foodName).font(.headline)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(prediction.estimatedCalories.cleanText) kcal")
                                    .font(.caption.bold())
                                Text("\((prediction.confidence * 100).rounded(toPlaces: 0), specifier: "%.0f")%")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
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
