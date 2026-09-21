import SwiftUI

@main
struct ChoreTrackerApp: App {
    @StateObject private var store = ChoreStore()
    @StateObject private var auth = AuthStore()
    @StateObject private var notifications = NotificationManager()
    @StateObject private var network = NetworkMonitor()

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.stage == .signedIn {
                    ContentView()
                } else {
                    AuthenticationView()
                }
            }
            .environmentObject(store)
            .environmentObject(auth)
            .environmentObject(notifications)
            .environmentObject(network)
        }
    }
}
