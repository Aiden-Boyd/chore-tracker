import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ChoreStore

    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house.fill") }

            if store.activeMember.role == .child {
                NavigationStack { ClaimableView() }
                    .tabItem { Label("Claim", systemImage: "hand.raised.fill") }
            }

            NavigationStack { HistoryView() }
                .tabItem { Label("History", systemImage: "calendar") }

            NavigationStack { ProfileView() }
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .tint(.indigo)
        .overlay(alignment: .bottom) {
            if let message = store.undoMessage {
                UndoBar(message: message) {
                    store.undoLastAction()
                } dismiss: {
                    store.dismissUndo()
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 64)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: store.undoMessage)
    }
}

struct UndoBar: View {
    let message: String
    let undo: () -> Void
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .font(.title3)
                .foregroundStyle(.indigo)

            Text(message)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)

            Spacer(minLength: 8)

            Button("Undo", action: undo)
                .font(.subheadline.bold())
                .foregroundStyle(.indigo)

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(.quaternary, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss undo")
        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .padding(.vertical, 11)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.quaternary, lineWidth: 1)
        )
        .shadow(radius: 8, y: 3)
    }
}

struct ProfileView: View {
    @EnvironmentObject private var store: ChoreStore
    @EnvironmentObject private var auth: AuthStore

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

            Section("Account") {
                LabeledContent("Email", value: auth.normalizedEmail)
                Button("Sign Out", role: .destructive) {
                    auth.signOut()
                }
            }

            if store.activeMember.role == .child {
                Section("Money") {
                    LabeledContent(
                        "Owed to you",
                        value: money(store.activeMemberMoneyOwedCents)
                    )
                    LabeledContent(
                        "Completed chores",
                        value: "\(store.activeMemberCompletedChores.count)"
                    )
                }
            }
        }
        .navigationTitle("Profile")
    }

    private func money(_ cents: Int) -> String {
        (Double(cents) / 100).formatted(.currency(code: "USD"))
    }
}
