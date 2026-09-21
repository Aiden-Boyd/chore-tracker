import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: ChoreStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.activeMember.role == .parent ? "Family chores" : "Hey, \(store.activeMember.name)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))

                    Text(store.activeMember.role == .parent
                         ? "Keep the house moving without keeping everything in your head."
                         : subtitle)
                        .foregroundStyle(.secondary)
                }

                if store.activeMember.role == .parent {
                    ParentSummaryCard()
                } else {
                    ProgressCard()
                }

                if store.activeMember.role == .child {
                    if store.myOpenChores.isEmpty {
                        ContentUnavailableView(
                            "You’re all caught up",
                            systemImage: "checkmark.circle.fill",
                            description: Text("Grab something from Claim if you want to help out.")
                        )
                        .padding(.top, 18)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Up next")
                                .font(.title3.bold())

                            ForEach(store.myOpenChores) { chore in
                                ChoreCard(chore: chore)
                            }
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Needs attention")
                            .font(.title3.bold())

                        if store.approvalQueue.isEmpty && store.overdueCount == 0 {
                            Text("Nothing urgent right now.")
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            if !store.approvalQueue.isEmpty {
                                AttentionRow(
                                    icon: "checkmark.seal.fill",
                                    title: "\(store.approvalQueue.count) waiting for approval",
                                    detail: "Review finished chores in Manage"
                                )
                            }

                            if store.overdueCount > 0 {
                                AttentionRow(
                                    icon: "exclamationmark.triangle.fill",
                                    title: "\(store.overdueCount) overdue",
                                    detail: "A few chores need a nudge"
                                )
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var subtitle: String {
        let count = store.myOpenChores.count
        if count == 0 { return "Nothing assigned right now." }
        if count == 1 { return "You’ve got 1 chore to knock out." }
        return "You’ve got \(count) chores to knock out."
    }
}

struct ProgressCard: View {
    @EnvironmentObject private var store: ChoreStore

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.indigo.opacity(0.12))
                    .frame(width: 58, height: 58)
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundStyle(.indigo)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(store.activeMemberPoints) points")
                    .font(.title2.bold())
                Text("\(store.activeMemberCompletedChores.count) chores completed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 22))
    }
}

struct ParentSummaryCard: View {
    @EnvironmentObject private var store: ChoreStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Family overview", systemImage: "person.3.fill")
                .font(.headline)

            HStack {
                SummaryMetric(value: "\(store.chores.filter { $0.status != .completed }.count)", label: "Open")
                Spacer()
                SummaryMetric(value: "\(store.claimableChores.count)", label: "Claimable")
                Spacer()
                SummaryMetric(value: "\(store.approvalQueue.count)", label: "Approve")
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 22))
    }
}

struct SummaryMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.title.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct AttentionRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 28)
                .foregroundStyle(.indigo)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct ChoreCard: View {
    @EnvironmentObject private var store: ChoreStore
    let chore: Chore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.indigo.opacity(0.12))
                        .frame(width: 42, height: 42)

                    Image(systemName: chore.kind == .claimable ? "hand.raised.fill" : "checklist")
                        .foregroundStyle(.indigo)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(chore.title)
                        .font(.headline)

                    if !chore.detail.isEmpty {
                        Text(chore.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                if chore.points > 0 {
                    Text("+\(chore.points)")
                        .font(.caption.bold())
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.indigo.opacity(0.1), in: Capsule())
                        .foregroundStyle(.indigo)
                }
            }

            HStack(spacing: 8) {
                InfoChip(icon: "repeat", text: chore.recurrence.label)

                if let dueDate = chore.dueDate {
                    DueChip(date: dueDate)
                }

                if chore.status == .awaitingApproval {
                    InfoChip(icon: "clock.fill", text: "Awaiting approval")
                }
            }

            if store.activeMember.role == .child &&
                chore.assignedTo == store.activeMemberID &&
                chore.status != .awaitingApproval {
                Button {
                    withAnimation {
                        store.complete(chore)
                    }
                } label: {
                    Label("Mark done", systemImage: "checkmark.circle.fill")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 22))
    }
}

struct InfoChip: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(.quaternary, in: Capsule())
    }
}

struct DueChip: View {
    let date: Date

    private var text: String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private var overdue: Bool {
        date < .now && !Calendar.current.isDateInToday(date)
    }

    var body: some View {
        Label(overdue ? "Overdue" : text, systemImage: overdue ? "exclamationmark.circle.fill" : "calendar")
            .font(.caption)
            .foregroundStyle(overdue ? .red : .secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background((overdue ? Color.red.opacity(0.1) : Color.secondary.opacity(0.1)), in: Capsule())
    }
}

struct ClaimableView: View {
    @EnvironmentObject private var store: ChoreStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Help out")
                        .font(.largeTitle.bold())
                    Text("Grab an open chore whenever you’ve got time.")
                        .foregroundStyle(.secondary)
                }

                if store.claimableChores.isEmpty {
                    ContentUnavailableView(
                        "Nothing to claim",
                        systemImage: "sparkles",
                        description: Text("The family chore pool is empty.")
                    )
                    .padding(.top, 40)
                } else {
                    ForEach(store.claimableChores) { chore in
                        VStack(alignment: .leading, spacing: 14) {
                            ChoreCardHeader(chore: chore)

                            if store.activeMember.role == .child {
                                Button {
                                    withAnimation {
                                        store.claim(chore)
                                    }
                                } label: {
                                    Label("Claim this chore", systemImage: "hand.raised.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding()
                        .background(.background, in: RoundedRectangle(cornerRadius: 22))
                    }
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ChoreCardHeader: View {
    let chore: Chore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(chore.title)
                    .font(.headline)
                Spacer()
                if chore.points > 0 {
                    Text("\(chore.points) pts")
                        .font(.caption.bold())
                        .foregroundStyle(.indigo)
                }
            }

            if !chore.detail.isEmpty {
                Text(chore.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                InfoChip(icon: "repeat", text: chore.recurrence.label)
                if let dueDate = chore.dueDate {
                    DueChip(date: dueDate)
                }
            }
        }
    }
}

struct ActivityView: View {
    @EnvironmentObject private var store: ChoreStore

    private var items: [Chore] {
        store.activeMember.role == .parent
            ? Array(store.completedChores)
            : Array(store.activeMemberCompletedChores)
    }

    var body: some View {
        List {
            if items.isEmpty {
                ContentUnavailableView(
                    "No activity yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Completed chores will show up here.")
                )
            } else {
                ForEach(items) { chore in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(chore.title)
                                .font(.headline)

                            Text(store.memberName(chore.assignedTo))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if chore.points > 0 {
                            Text("+\(chore.points)")
                                .font(.caption.bold())
                                .foregroundStyle(.indigo)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Activity")
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
                            Text(chore.title)
                                .font(.headline)

                            Text("Completed by \(store.memberName(chore.assignedTo))")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack {
                                Button("Send back") {
                                    store.reopen(chore)
                                }
                                .buttonStyle(.bordered)

                                Button("Approve") {
                                    withAnimation {
                                        store.approve(chore)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Active chores") {
                ForEach(store.chores.filter { $0.status != .completed }) { chore in
                    NavigationLink {
                        EditChoreView(chore: chore)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(chore.title)

                                Text(chore.kind == .claimable ? "Anyone can claim" : store.memberName(chore.assignedTo))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if let due = chore.dueDate {
                                Text(due, format: .dateTime.month(.abbreviated).day())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            store.delete(chore)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
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
                ChoreEditorView()
            }
        }
    }
}

struct ChoreEditorView: View {
    @EnvironmentObject private var store: ChoreStore
    @Environment(\.dismiss) private var dismiss

    var existingChore: Chore?

    @State private var title = ""
    @State private var detail = ""
    @State private var kind: ChoreKind = .assigned
    @State private var recurrence: Recurrence = .once
    @State private var assignee: UUID?
    @State private var requiresApproval = true
    @State private var points = 0
    @State private var hasDueDate = false
    @State private var dueDate = Date()

    init(existingChore: Chore? = nil) {
        self.existingChore = existingChore
        _title = State(initialValue: existingChore?.title ?? "")
        _detail = State(initialValue: existingChore?.detail ?? "")
        _kind = State(initialValue: existingChore?.kind ?? .assigned)
        _recurrence = State(initialValue: existingChore?.recurrence ?? .once)
        _assignee = State(initialValue: existingChore?.assignedTo)
        _requiresApproval = State(initialValue: existingChore?.requiresApproval ?? true)
        _points = State(initialValue: existingChore?.points ?? 0)
        _hasDueDate = State(initialValue: existingChore?.dueDate != nil)
        _dueDate = State(initialValue: existingChore?.dueDate ?? Date())
    }

    var body: some View {
        Form {
            Section("Chore") {
                TextField("What needs to be done?", text: $title)
                TextField("Notes or instructions", text: $detail, axis: .vertical)
                    .lineLimit(2...5)
            }

            Section("Who") {
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

                Toggle("Set due date", isOn: $hasDueDate)

                if hasDueDate {
                    DatePicker("Due", selection: $dueDate)
                }
            }

            Section("Completion") {
                Toggle("Require parent approval", isOn: $requiresApproval)
                Stepper("Points: \(points)", value: $points, in: 0...100, step: 5)
            }
        }
        .navigationTitle(existingChore == nil ? "New Chore" : "Edit Chore")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                    dismiss()
                }
                .disabled(
                    title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    (kind == .assigned && assignee == nil)
                )
            }
        }
    }

    private func save() {
        if let existingChore {
            store.updateChore(
                existingChore,
                title: title,
                detail: detail,
                kind: kind,
                recurrence: recurrence,
                dueDate: hasDueDate ? dueDate : nil,
                assignee: assignee,
                requiresApproval: requiresApproval,
                points: points
            )
        } else {
            store.addChore(
                title: title,
                detail: detail,
                kind: kind,
                recurrence: recurrence,
                dueDate: hasDueDate ? dueDate : nil,
                assignee: assignee,
                requiresApproval: requiresApproval,
                points: points
            )
        }
    }
}

struct EditChoreView: View {
    let chore: Chore

    var body: some View {
        ChoreEditorView(existingChore: chore)
    }
}
