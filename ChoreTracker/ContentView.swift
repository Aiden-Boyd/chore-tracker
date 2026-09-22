import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ChoreStore
    @EnvironmentObject private var notifications: NotificationManager

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

            if store.activeMember.role == .parent {
                NavigationStack { PaymentHistoryView() }
                    .tabItem { Label("Payments", systemImage: "banknote.fill") }
            }

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
        .task {
            await notifications.reschedule(for: store)
        }
        .onChange(of: store.chores) { _, _ in
            Task { await notifications.reschedule(for: store) }
        }
        .onChange(of: store.activeMemberID) { _, _ in
            Task { await notifications.reschedule(for: store) }
        }
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
    @State private var showingDeleteAccount = false
    @State private var deleteError: String?

    var body: some View {
        List {
            Section("Viewing as") {
                Picker("Family member", selection: $store.activeMemberID) {
                    ForEach(store.members.filter { $0.archivedAt == nil }) { member in
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

                    if !store.archivedChildren.isEmpty {
                        NavigationLink {
                            ArchivedChildrenView()
                        } label: {
                            Label("Archived children", systemImage: "archivebox")
                        }
                    }
                }
            }

            Section("Data") {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Available offline")
                        Text("Household data is stored on this device and isolated to this signed-in account.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "externaldrive.fill.badge.checkmark")
                        .foregroundStyle(.green)
                }
            }

            Section("Account") {
                LabeledContent("Email", value: auth.normalizedEmail)

                NavigationLink {
                    NotificationSettingsView()
                } label: {
                    Label("Notifications", systemImage: "bell.badge")
                }

                Button("Sign Out", role: .destructive) {
                    auth.signOut()
                }

                Button("Delete Account", role: .destructive) {
                    showingDeleteAccount = true
                }

                if let deleteError {
                    Text(deleteError)
                        .font(.caption)
                        .foregroundStyle(.red)
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

                    NavigationLink {
                        MoneyLedgerView(memberID: store.activeMemberID)
                    } label: {
                        Label("Money history", systemImage: "list.bullet.rectangle")
                    }
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
        .confirmationDialog(
            "Delete your account?",
            isPresented: $showingDeleteAccount,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                Task {
                    do {
                        try await auth.deleteAccount()
                        store.deleteCurrentAccountData()
                    } catch {
                        deleteError = error.localizedDescription
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your sign-in account and removes this household’s local chores, rewards, and payment history from this device.")
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

                        NavigationLink {
                            MoneyLedgerView(memberID: memberID)
                        } label: {
                            Label("Money history", systemImage: "list.bullet.rectangle")
                        }
                    }

                    Section("Profile") {
                        Button {
                            showingRename = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
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
                            Button("Archive Child", role: .destructive) {
                                showingRemoveConfirmation = true
                            }
                        } footer: {
                            Text("Archiving hides this child from active household lists but keeps chores, rewards, and history.")
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
                .confirmationDialog(
                    "Archive \(member.name)?",
                    isPresented: $showingRemoveConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Archive Child", role: .destructive) {
                        store.archiveManagedChild(memberID)
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This keeps all history and rewards but removes the child from active household lists.")
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

struct MoneyLedgerView: View {
    @EnvironmentObject private var store: ChoreStore

    let memberID: UUID

    private var entries: [Chore] {
        store.ledgerEntries(for: memberID)
    }

    private var memberName: String {
        store.memberName(memberID)
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    ledgerSummary(
                        title: "Earned",
                        amount: store.totalEarnedCents(for: memberID),
                        icon: "dollarsign.circle.fill"
                    )

                    ledgerSummary(
                        title: "Paid",
                        amount: store.totalPaidCents(for: memberID),
                        icon: "checkmark.circle.fill"
                    )

                    ledgerSummary(
                        title: "Owed",
                        amount: store.moneyOwedCents(to: memberID),
                        icon: "clock.fill"
                    )
                }
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 8)
            }

            Section("Activity") {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No reward history",
                        systemImage: "dollarsign.circle",
                        description: Text("Completed chores with rewards will appear here.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(entries) { chore in
                        HStack(spacing: 12) {
                            Text(chore.emoji)
                                .font(.title3)
                                .frame(width: 42, height: 42)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(chore.title)
                                    .font(.body.weight(.medium))

                                Text(ledgerSubtitle(chore))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 3) {
                                Text(money(chore.rewardCents))
                                    .font(.subheadline.bold())

                                Text(chore.paidAt == nil ? "Owed" : "Paid")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(chore.paidAt == nil ? .orange : .green)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        }
        .navigationTitle("\(memberName)’s Money")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func ledgerSummary(title: String, amount: Int, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon)
                .foregroundStyle(.indigo)

            Text(money(amount))
                .font(.headline)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
    }

    private func ledgerSubtitle(_ chore: Chore) -> String {
        let completed = chore.completedAt?.formatted(date: .abbreviated, time: .shortened) ?? "Completed"
        if let paidAt = chore.paidAt {
            return "\(completed) · Paid \(paidAt.formatted(date: .abbreviated, time: .omitted))"
        }
        return completed
    }

    private func money(_ cents: Int) -> String {
        (Double(cents) / 100).formatted(.currency(code: "USD"))
    }
}

private enum PaymentHistoryScope: String, CaseIterable, Identifiable {
    case weekly = "Weekly"
    case monthly = "Monthly"

    var id: String { rawValue }

    var calendarComponent: Calendar.Component {
        switch self {
        case .weekly: .weekOfYear
        case .monthly: .month
        }
    }
}

struct PaymentHistoryView: View {
    @EnvironmentObject private var store: ChoreStore

    @State private var scope: PaymentHistoryScope = .weekly
    @State private var periodOffset = 0

    private var calendar: Calendar { .current }

    private var periodDate: Date {
        calendar.date(
            byAdding: scope.calendarComponent,
            value: periodOffset,
            to: .now
        ) ?? .now
    }

    private var interval: DateInterval {
        calendar.dateInterval(of: scope.calendarComponent, for: periodDate)
            ?? DateInterval(start: calendar.startOfDay(for: periodDate), duration: 86_400)
    }

    private var children: [FamilyMember] {
        store.children + store.archivedChildren
    }

    private var totalPaidCents: Int {
        children.reduce(0) { total, child in
            total + paidEntries(for: child.id).reduce(0) { $0 + $1.rewardCents }
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Payment period", selection: $scope) {
                    ForEach(PaymentHistoryScope.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                HStack(spacing: 14) {
                    Button {
                        periodOffset -= 1
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 38, height: 38)
                            .background(.quaternary, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Previous \(scope.rawValue.lowercased()) period")

                    VStack(spacing: 3) {
                        Text(periodTitle)
                            .font(.headline)

                        Text(periodOffset == 0 ? "Current period" : "Past period")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Button {
                        periodOffset += 1
                    } label: {
                        Image(systemName: "chevron.right")
                            .frame(width: 38, height: 38)
                            .background(.quaternary, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(periodOffset >= 0)
                    .accessibilityLabel("Next \(scope.rawValue.lowercased()) period")
                }
                .padding(.vertical, 4)
            }

            Section {
                HStack(spacing: 14) {
                    Image(systemName: "banknote.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                        .frame(width: 48, height: 48)
                        .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 15))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(money(totalPaidCents))
                            .font(.title2.bold())

                        Text("Paid across the household")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 5)
            }

            Section("By child") {
                if children.isEmpty {
                    ContentUnavailableView(
                        "No children yet",
                        systemImage: "person.2",
                        description: Text("Add a child to begin tracking payments.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(children) { child in
                        let entries = paidEntries(for: child.id)
                        let amount = entries.reduce(0) { $0 + $1.rewardCents }

                        NavigationLink {
                            ChildPaymentPeriodView(
                                member: child,
                                entries: entries,
                                periodTitle: periodTitle
                            )
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(.indigo.opacity(0.12))
                                    .frame(width: 42, height: 42)
                                    .overlay(
                                        Text(String(child.name.prefix(1)).uppercased())
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.indigo)
                                    )

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(child.name)
                                            .font(.body.weight(.medium))

                                        if child.archivedAt != nil {
                                            Text("Archived")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(.quaternary, in: Capsule())
                                        }
                                    }

                                    Text(entries.isEmpty
                                         ? "No payments"
                                         : "\(entries.count) rewarded chore\(entries.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(money(amount))
                                    .font(.headline)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
            }
        }
        .navigationTitle("Payments")
        .onChange(of: scope) { _, _ in
            periodOffset = 0
        }
    }

    private var periodTitle: String {
        switch scope {
        case .weekly:
            let lastDay = interval.end.addingTimeInterval(-1)
            return "\(interval.start.formatted(date: .abbreviated, time: .omitted)) – \(lastDay.formatted(date: .abbreviated, time: .omitted))"
        case .monthly:
            return periodDate.formatted(.dateTime.month(.wide).year())
        }
    }

    private func paidEntries(for memberID: UUID) -> [Chore] {
        store.ledgerEntries(for: memberID)
            .filter { chore in
                guard let paidAt = chore.paidAt else { return false }
                return interval.contains(paidAt)
            }
            .sorted { ($0.paidAt ?? .distantPast) > ($1.paidAt ?? .distantPast) }
    }

    private func money(_ cents: Int) -> String {
        (Double(cents) / 100).formatted(.currency(code: "USD"))
    }
}

private struct ChildPaymentPeriodView: View {
    let member: FamilyMember
    let entries: [Chore]
    let periodTitle: String

    private var totalPaidCents: Int {
        entries.reduce(0) { $0 + $1.rewardCents }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 7) {
                    Text(money(totalPaidCents))
                        .font(.largeTitle.bold())

                    Text("Paid during \(periodTitle)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section("Paid chores") {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No payments",
                        systemImage: "banknote",
                        description: Text("No money was marked paid to \(member.name) during this period.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(entries) { chore in
                        HStack(spacing: 12) {
                            Text(chore.emoji)
                                .font(.title3)
                                .frame(width: 42, height: 42)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(chore.title)
                                    .font(.body.weight(.medium))

                                if let paidAt = chore.paidAt {
                                    Text("Paid \(paidAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Text(money(chore.rewardCents))
                                .font(.subheadline.bold())
                                .foregroundStyle(.green)
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        }
        .navigationTitle(member.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func money(_ cents: Int) -> String {
        (Double(cents) / 100).formatted(.currency(code: "USD"))
    }
}

struct ArchivedChildrenView: View {
    @EnvironmentObject private var store: ChoreStore

    var body: some View {
        List {
            if store.archivedChildren.isEmpty {
                ContentUnavailableView(
                    "No archived children",
                    systemImage: "archivebox",
                    description: Text("Archived household members will appear here.")
                )
            } else {
                ForEach(store.archivedChildren) { child in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(.secondary.opacity(0.12))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(String(child.name.prefix(1)).uppercased())
                                    .font(.subheadline.bold())
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(child.name)
                                .font(.body.weight(.medium))

                            Text("History and rewards preserved")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Restore") {
                            store.restoreManagedChild(child.id)
                        }
                        .font(.subheadline.bold())
                    }

                    NavigationLink {
                        MoneyLedgerView(memberID: child.id)
                    } label: {
                        Label("View \(child.name)’s money history", systemImage: "dollarsign.circle")
                    }
                }
            }
        }
        .navigationTitle("Archived Children")
        .navigationBarTitleDisplayMode(.inline)
    }
}


struct NotificationSettingsView: View {
    @EnvironmentObject private var store: ChoreStore
    @EnvironmentObject private var notifications: NotificationManager

    @AppStorage(NotificationManager.Keys.notificationsEnabled)
    private var notificationsEnabled = true

    @AppStorage(NotificationManager.Keys.dueReminders)
    private var dueReminders = true

    @AppStorage(NotificationManager.Keys.overdueReminders)
    private var overdueReminders = true

    @AppStorage(NotificationManager.Keys.approvalReminders)
    private var approvalReminders = true

    @AppStorage(NotificationManager.Keys.reminderLeadMinutes)
    private var reminderLeadMinutes = 60

    var body: some View {
        Form {
            Section {
                Toggle("Allow chore notifications", isOn: $notificationsEnabled)
            } footer: {
                Text(statusText)
            }

            if notificationsEnabled {
                if store.activeMember.role == .child {
                    Section("Chore reminders") {
                        Toggle("Due soon", isOn: $dueReminders)
                        Toggle("Overdue chores", isOn: $overdueReminders)

                        if dueReminders {
                            Picker("Remind me", selection: $reminderLeadMinutes) {
                                Text("15 minutes before").tag(15)
                                Text("30 minutes before").tag(30)
                                Text("1 hour before").tag(60)
                                Text("2 hours before").tag(120)
                                Text("1 day before").tag(1440)
                            }
                        }
                    }
                } else {
                    Section("Parent reminders") {
                        Toggle("Chores waiting for approval", isOn: $approvalReminders)
                    }
                }

                Section {
                    Button {
                        Task {
                            await notifications.requestPermission()
                            await notifications.reschedule(for: store)
                        }
                    } label: {
                        Label(permissionButtonTitle, systemImage: "bell.badge.fill")
                    }
                }
            }

            Section {
                Text("Due, overdue, and approval reminders are scheduled locally on this device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await notifications.refreshAuthorizationStatus()
        }
        .onChange(of: notificationsEnabled) { _, _ in reschedule() }
        .onChange(of: dueReminders) { _, _ in reschedule() }
        .onChange(of: overdueReminders) { _, _ in reschedule() }
        .onChange(of: approvalReminders) { _, _ in reschedule() }
        .onChange(of: reminderLeadMinutes) { _, _ in reschedule() }
    }

    private var statusText: String {
        switch notifications.authorizationStatus {
        case .authorized, .provisional:
            return "Notifications are allowed on this device."
        case .denied:
            return "Notifications are blocked in iOS Settings."
        case .notDetermined:
            return "Turn on reminders, then allow notifications when iOS asks."
        case .ephemeral:
            return "Notifications are temporarily allowed."
        @unknown default:
            return "Notification permission status is unavailable."
        }
    }

    private var permissionButtonTitle: String {
        switch notifications.authorizationStatus {
        case .authorized, .provisional:
            return "Refresh notification schedule"
        case .denied:
            return "Notifications blocked in Settings"
        default:
            return "Allow Notifications"
        }
    }

    private func reschedule() {
        Task {
            await notifications.reschedule(for: store)
        }
    }
}
