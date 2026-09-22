import SwiftUI

@main
struct ChoreTrackerApp: App {
    @StateObject private var store = ChoreStore()
    @StateObject private var auth = AuthStore()
    @StateObject private var notifications = NotificationManager()
    @StateObject private var network = NetworkMonitor()

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .top) {
                Group {
                    if auth.stage == .signedIn {
                        ContentView()
                    } else {
                        AuthenticationView()
                    }
                }

                if network.state != .online {
                    NetworkStatusBanner(state: network.state)
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(10)
                }
            }
            .animation(.easeOut(duration: 0.2), value: network.state)
            .environmentObject(store)
            .environmentObject(auth)
            .environmentObject(notifications)
            .environmentObject(network)
            .task(id: auth.stage) {
                guard auth.stage == .signedIn else { return }
                store.activateAccount(
                    email: auth.normalizedEmail,
                    name: auth.name,
                    role: auth.role
                )
                await auth.validateSession()
            }
        }
    }
}
