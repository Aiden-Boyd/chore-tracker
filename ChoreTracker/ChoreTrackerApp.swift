import SwiftUI

@main
struct ChoreTrackerApp: App {
    @StateObject private var store = ChoreStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
