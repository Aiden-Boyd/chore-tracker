import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ChoreStore

    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack { ClaimableView() }
                .tabItem { Label("Claim", systemImage: "hand.raised.fill") }

            NavigationStack { ActivityView() }
                .tabItem { Label("Activity", systemImage: "clock.arrow.circlepath") }

            if store.activeMember.role == .parent {
                NavigationStack { ParentView() }
                    .tabItem { Label("Manage", systemImage: "slider.horizontal.3") }
                    .badge(store.approvalQueue.count)
            }

            NavigationStack { ProfileView() }
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .tint(.indigo)
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

            if store.activeMember.role == .child {
                Section("Your progress") {
                    LabeledContent("Points earned", value: "\(store.activeMemberPoints)")
                    LabeledContent("Completed", value: "\(store.activeMemberCompletedChores.count)")
                }
            }

            Section("About") {
                Label("Family chores, without the nagging.", systemImage: "sparkles")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Profile")
    }
}
