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
                        NavigationLink {
                            ChildProfileView(memberID: child.id)
                        } label: {
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
                            }
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


struct ChildProfileView: View {
    @EnvironmentObject private var store: ChoreStore
    @Environment(\.dismiss) private var dismiss

    let memberID: UUID

    @State private var showingRename = false
    @State private var showingRemoveConfirmation = false
    @State private var showingConnectAccount = false

    private var member: FamilyMember? {
        store.members.first(where: { $0.id == memberID })
    }

    private var openChores: [Chore] {
        store.chores.filter {
            ($0.assignedTo == memberID || $0.claimedBy == memberID) &&
            $0.status != .completed
        }
    }

    private var completedCount: Int {
        store.completedChores.filter {
            $0.assignedTo == memberID || $0.claimedBy == memberID
        }.count
    }

    var body: some View {
        Group {
            if let member {
                List {
                    Section {
                        VStack(spacing: 12) {
                            Circle()
                                .fill(.indigo.opacity(0.12))
                                .frame(width: 82, height: 82)
                                .overlay(
                                    Text(String(member.name.prefix(1)).uppercased())
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                        .foregroundStyle(.indigo)
                                )

                            Text(member.name)
                                .font(.title2.bold())

                            Label(
                                member.isManagedProfile ? "Managed by parent" : "Has an account",
                                systemImage: member.isManagedProfile ? "person.crop.circle.badge.checkmark" : "checkmark.seal.fill"
                            )
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }

                    Section("Overview") {
                        LabeledContent("Active chores", value: "\(openChores.count)")
                        LabeledContent("Completed chores", value: "\(completedCount)")
                        LabeledContent(
                            "Money owed",
                            value: (Double(store.moneyOwedCents(to: memberID)) / 100)
                                .formatted(.currency(code: "USD"))
                        )
                    }

                    Section("Profile") {
                        Button {
                            showingRename = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }

                        if member.isManagedProfile {
                            Button {
                                showingConnectAccount = true
                            } label: {
                                Label("Connect an account", systemImage: "person.crop.circle.badge.plus")
                            }
                        }
                    }

                    if member.isManagedProfile {
                        Section {
                            Text("This child does not need their own device or login. Their chores, rewards, and history are managed from the household.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if member.isManagedProfile {
                        Section {
                            Button("Remove Child", role: .destructive) {
                                showingRemoveConfirmation = true
                            }
                        } footer: {
                            Text("Removing this child also removes chores and history currently tied to this local profile.")
                        }
                    }
                }
                .navigationTitle("Child Profile")
                .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showingRename) {
                    NavigationStack {
                        RenameChildView(memberID: memberID, currentName: member.name)
                    }
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                }
                .sheet(isPresented: $showingConnectAccount) {
                    NavigationStack {
                        ConnectChildAccountView(memberID: memberID)
                    }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
                .confirmationDialog(
                    "Remove \(member.name)?",
                    isPresented: $showingRemoveConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Remove Child", role: .destructive) {
                        store.removeManagedChild(memberID)
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This removes the managed profile and chores/history associated with it on this device.")
                }
            } else {
                ContentUnavailableView(
                    "Child not found",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text("This household member is no longer available.")
                )
            }
        }
    }
}

struct RenameChildView: View {
    @EnvironmentObject private var store: ChoreStore
    @Environment(\.dismiss) private var dismiss

    let memberID: UUID
    @State private var name: String
    @FocusState private var focused: Bool

    init(memberID: UUID, currentName: String) {
        self.memberID = memberID
        _name = State(initialValue: currentName)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 20) {
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

            Button("Save") {
                save()
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canSave ? Color.indigo : Color.secondary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
            .buttonStyle(SoftPressStyle())
            .disabled(!canSave)

            Spacer()
        }
        .padding(24)
        .navigationTitle("Rename Child")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .onAppear { focused = true }
    }

    private func save() {
        store.renameMember(memberID, name: name)
        dismiss()
    }
}

struct ConnectChildAccountView: View {
    @EnvironmentObject private var store: ChoreStore
    @Environment(\.dismiss) private var dismiss

    let memberID: UUID

    private var childName: String {
        store.members.first(where: { $0.id == memberID })?.name ?? "This child"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 54))
                    .foregroundStyle(.indigo)
                    .padding(.top, 8)

                VStack(spacing: 8) {
                    Text("Connect \(childName)’s account")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    Text("When they get a phone or other device, you’ll be able to connect a New Life Media account to this existing child profile instead of creating a new one.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 14) {
                    accountCarryoverRow("Existing chores", icon: "checklist")
                    accountCarryoverRow("Completion history", icon: "calendar")
                    accountCarryoverRow("Money and rewards", icon: "dollarsign.circle")
                    accountCarryoverRow("Same household profile", icon: "house")
                }
                .padding(18)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 20))

                VStack(spacing: 8) {
                    Label("Shared account linking isn’t enabled yet", systemImage: "wrench.and.screwdriver")
                        .font(.subheadline.weight(.semibold))

                    Text("The profile is ready for it. Once the household endpoints are added to the shared auth service, this button will send an invite and link the resulting account to this same member ID.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button("Done") {
                    dismiss()
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.indigo, in: RoundedRectangle(cornerRadius: 16))
                .buttonStyle(SoftPressStyle())
            }
            .padding(24)
        }
        .navigationTitle("Connect Account")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func accountCarryoverRow(_ title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.indigo)
                .frame(width: 24)

            Text(title)
                .font(.subheadline.weight(.medium))

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }
}
