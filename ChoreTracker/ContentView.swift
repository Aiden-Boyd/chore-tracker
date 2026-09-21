import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ChoreStore

    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }

            NavigationStack {
                ClaimableView()
            }
            .tabItem {
                Label("Claim", systemImage: "hand.raised.fill")
            }

            if store.activeMember.role == .parent {
                NavigationStack {
                    ParentView()
                }
                .tabItem {
                    Label("Manage", systemImage: "slider.horizontal.3")
                }
            }

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle")
            }
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject private var store: ChoreStore

    var body: some View {
        List {
            Section("Viewing as") {
                Picker("Family member", selection: $store.activeMemberID) {
                    ForEach(store.members) { member in
                        Text("\(member.name) · \(member.role.rawValue.capitalized)")
                            .tag(member.id)
                    }
                }
            }

            Section("Prototype") {
                Text("Switch family members here to test both the parent and child experience.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Profile")
    }
}
