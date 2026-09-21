import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: ChoreStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hey, \(store.activeMember.name)")
                        .font(.largeTitle.bold())
                    Text(store.activeMember.role == .parent ? "Here’s what the family has going on." : "Here’s what you need to get done.")
                        .foregroundStyle(.secondary)
                }

                if store.activeMember.role == .parent {
                    ParentSummaryCard()
                } else if store.myOpenChores.isEmpty {
                    ContentUnavailableView("All done", systemImage: "checkmark.circle", description: Text("You don’t have any assigned chores right now."))
                } else {
                    VStack(spacing: 12) {
                        ForEach(store.myOpenChores) { chore in
                            ChoreCard(chore: chore)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Chores")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ParentSummaryCard: View {
    @EnvironmentObject private var store: ChoreStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Family overview", systemImage: "person.3.fill")
                .font(.headline)

            HStack {
                SummaryMetric(value: "\(store.chores.filter { $0.status != .completed }.count)", label: "Open")
                Spacer()
                SummaryMetric(value: "\(store.claimableChores.count)", label: "Claimable")
                Spacer()
                SummaryMetric(value: "\(store.approvalQueue.count)", label: "To approve")
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct SummaryMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(value).font(.title2.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct ChoreCard: View {
    @EnvironmentObject private var store: ChoreStore
    let chore: Chore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(chore.title)
                        .font(.headline)
                    if !chore.detail.isEmpty {
                        Text(chore.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if chore.points > 0 {
                    Text("+\(chore.points)")
                        .font(.caption.bold())
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.quaternary, in: Capsule())
                }
            }

            HStack {
                Label(chore.recurrence.label, systemImage: "repeat")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if chore.status == .awaitingApproval {
                    Label("Waiting for approval", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            if store.activeMember.role == .child &&
                chore.assignedTo == store.activeMemberID &&
                chore.status != .awaitingApproval {
                Button {
                    store.complete(chore)
                } label: {
                    Label("Mark done", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}

struct ClaimableView: View {
    @EnvironmentObject private var store: ChoreStore

    var body: some View {
        List {
            if store.claimableChores.isEmpty {
                ContentUnavailableView("Nothing to claim", systemImage: "sparkles", description: Text("There aren’t any open family chores right now."))
            } else {
                ForEach(store.claimableChores) { chore in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(chore.title).font(.headline)
                                Text(chore.recurrence.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if chore.points > 0 {
                                Text("\(chore.points) pts")
                                    .font(.caption.bold())
                            }
                        }

                        if store.activeMember.role == .child {
                            Button("Claim chore") {
                                store.claim(chore)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Claimable")
    }
}

struct ParentView: View {
    @EnvironmentObject private var store: ChoreStore
    @State private var showingNewChore = false

    var body: some View {
        List {
            if !store.approvalQueue.isEmpty {
                Section("Needs approval") {
                    ForEach(store.approvalQueue) { chore in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(chore.title).font(.headline)
                            Text("Completed by \(store.memberName(chore.assignedTo))")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack {
                                Button("Send back") {
                                    store.reopen(chore)
                                }
                                .buttonStyle(.bordered)

                                Button("Approve") {
                                    store.approve(chore)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("All chores") {
                ForEach(store.chores) { chore in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(chore.title)
                            Text(chore.kind == .claimable ? "Anyone can claim" : store.memberName(chore.assignedTo))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(chore.status.rawValue.replacingOccurrences(of: "awaitingApproval", with: "approval").capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Manage")
        .toolbar {
            Button {
                showingNewChore = true
            } label: {
                Label("New chore", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showingNewChore) {
            NavigationStack {
                NewChoreView()
            }
        }
    }
}

struct NewChoreView: View {
    @EnvironmentObject private var store: ChoreStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var detail = ""
    @State private var kind: ChoreKind = .assigned
    @State private var recurrence: Recurrence = .once
    @State private var assignee: UUID?
    @State private var requiresApproval = true
    @State private var points = 0

    var body: some View {
        Form {
            Section("Chore") {
                TextField("Title", text: $title)
                TextField("Notes", text: $detail, axis: .vertical)
            }

            Section("Who does it?") {
                Picker("Type", selection: $kind) {
                    Text("Assign to someone").tag(ChoreKind.assigned)
                    Text("Anyone can claim").tag(ChoreKind.claimable)
                }

                if kind == .assigned {
                    Picker("Assign to", selection: $assignee) {
                        Text("Choose").tag(UUID?.none)
                        ForEach(store.children) { child in
                            Text(child.name).tag(Optional(child.id))
                        }
                    }
                }
            }

            Section("Schedule") {
                Picker("Repeats", selection: $recurrence) {
                    ForEach(Recurrence.allCases) { recurrence in
                        Text(recurrence.label).tag(recurrence)
                    }
                }
            }

            Section("Completion") {
                Toggle("Require parent approval", isOn: $requiresApproval)
                Stepper("Points: \(points)", value: $points, in: 0...100, step: 5)
            }
        }
        .navigationTitle("New Chore")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    store.addChore(
                        title: title,
                        detail: detail,
                        kind: kind,
                        recurrence: recurrence,
                        assignee: assignee,
                        requiresApproval: requiresApproval,
                        points: points
                    )
                    dismiss()
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (kind == .assigned && assignee == nil))
            }
        }
    }
}
