import SwiftUI

@main
struct PantreeApp: App {
    @StateObject private var store: LocalFoodStore

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let isUITest = arguments.contains("-UITestMode")
        let fileURL = isUITest
            ? FileManager.default.temporaryDirectory.appendingPathComponent("pantree-ui-test-store.json")
            : LocalFoodStore.defaultFileURL()
        let localStore = LocalFoodStore(fileURL: fileURL, seedIfEmpty: true)
        if isUITest {
            try? localStore.reset(items: SampleData.initialInventory(now: SampleData.referenceDate), events: [])
        }
        _store = StateObject(wrappedValue: localStore)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
