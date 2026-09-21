import SwiftUI

@main
struct ChoreTrackerApp: App {
    @StateObject private var store = ChoreStore()
    @StateObject private var auth = AuthStore()

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
        }
    }
}
