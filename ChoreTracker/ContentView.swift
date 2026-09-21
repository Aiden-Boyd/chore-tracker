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
    @State private var showingAddChild = false

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

            if store.activeMember.role == .parent {
                Section("Household") {
                    ForEach(store.children) { child in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(.indigo.opacity(0.12))
                                .frame(width: 38, height: 38)
                                .overlay(
                                    Text(String(child.name.prefix(1)).uppercased())
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.indigo)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(child.name)
                                    .font(.body.weight(.medium))

                                Text(child.isManagedProfile ? "Managed child · no phone needed" : "Child account")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                    }

                    Button {
                        showingAddChild = true
                    } label: {
                        Label("Add child", systemImage: "person.badge.plus")
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
        .sheet(isPresented: $showingAddChild) {
            NavigationStack {
                AddManagedChildView()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private func money(_ cents: Int) -> String {
        (Double(cents) / 100).formatted(.currency(code: "USD"))
    }
}


struct AddManagedChildView: View {
    @EnvironmentObject private var store: ChoreStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @FocusState private var focused: Bool

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
                Image(systemName: "figure.child.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.indigo)

                Text("Add a child")
                    .font(.title2.bold())

                Text("They don’t need a phone, email, or account. You can assign chores and track rewards for them from your household.")
                    .multilineTextAlignment(.center)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            TextField("Child’s name", text: $name)
                .textInputAutocapitalization(.words)
                .textContentType(.name)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit {
                    if canSave { save() }
                }
                .padding(14)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))

            Button {
                save()
            } label: {
                Text("Add Child")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canSave ? Color.indigo : Color.secondary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(SoftPressStyle())
            .disabled(!canSave)

            Spacer()
        }
        .padding(24)
        .navigationTitle("New Child")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .onAppear { focused = true }
    }

    private func save() {
        store.addManagedChild(name: name)
        dismiss()
    }
}
