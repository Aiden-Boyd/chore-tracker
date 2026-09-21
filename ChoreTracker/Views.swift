import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: ChoreStore
    @State private var showingNewChore = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if store.activeMember.role == .parent {
                    parentHome
                } else {
                    childHome
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingNewChore) {
            NavigationStack {
                ChoreEditorView()
            }
            .presentationDetents([.large])
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: store.chores)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text(store.activeMember.role == .parent ? "Home" : "Hey, \(store.activeMember.name)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))

                Text(store.activeMember.role == .parent
                     ? "Everything you need, in one place."
                     : childSubtitle)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if store.activeMember.role == .parent {
                Button {
                    showingNewChore = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.bold())
                        .frame(width: 46, height: 46)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(Circle())
                .accessibilityLabel("Add chore")
            }
        }
    }

    @ViewBuilder
    private var parentHome: some View {
        MoneyOwedCard()

        if !store.approvalQueue.isEmpty {
            ParentApprovalSection()
        }

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Chores")
                    .font(.title3.bold())
                Spacer()
                Text("\(store.activeChores.count) active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if store.activeChores.isEmpty {
                EmptyHomeCard(
                    emoji: "🎉",
                    title: "Nothing active",
                    subtitle: "Tap + to add a chore."
                )
            } else {
                ForEach(store.activeChores) { chore in
                    NavigationLink {
                        EditChoreView(chore: chore)
                    } label: {
                        ParentChoreRow(chore: chore)
                    }
                    .buttonStyle(.plain)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .scale(scale: 0.96)),
                            removal: .move(edge: .trailing).combined(with: .scale(scale: 0.82))
                        )
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var childHome: some View {
        ChildMoneyCard()

        VStack(alignment: .leading, spacing: 12) {
            Text("Your chores")
                .font(.title3.bold())

            if store.myOpenChores.isEmpty {
                EmptyHomeCard(
                    emoji: "🙌",
                    title: "You’re all caught up",
                    subtitle: "Check Claim if you want to grab something extra."
                )
            } else {
                ForEach(store.myOpenChores) { chore in
                    ChoreCard(chore: chore)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .scale(scale: 0.96)),
                                removal: .move(edge: .trailing).combined(with: .scale(scale: 0.82))
                            )
                        )
                }
            }
        }
    }

    private var childSubtitle: String {
        let count = store.myOpenChores.count
        if count == 0 { return "Nothing assigned right now." }
        if count == 1 { return "One thing to knock out." }
        return "\(count) things to knock out."
    }
}

struct MoneyOwedCard: View {
    @EnvironmentObject private var store: ChoreStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Money owed")
                        .font(.headline)
                    Text(money(store.totalMoneyOwedCents))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                }

                Spacer()

                Text("💵")
                    .font(.system(size: 38))
            }

            if store.totalMoneyOwedCents == 0 {
                Text("You’re all settled up.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Divider()

                ForEach(store.children) { child in
                    let owed = store.moneyOwedCents(to: child.id)
                    if owed > 0 {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(child.name)
                                    .font(.headline)
                                Text(money(owed))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Mark paid") {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                                    store.markPaid(to: child.id)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 24))
    }

    private func money(_ cents: Int) -> String {
        (Double(cents) / 100).formatted(.currency(code: "USD"))
    }
}

struct ChildMoneyCard: View {
    @EnvironmentObject private var store: ChoreStore

    var body: some View {
        HStack(spacing: 16) {
            Text("💵")
                .font(.system(size: 38))

            VStack(alignment: .leading, spacing: 2) {
                Text("Money owed to you")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text((Double(store.activeMemberMoneyOwedCents) / 100).formatted(.currency(code: "USD")))
                    .font(.title2.bold())
            }

            Spacer()
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 22))
    }
}

struct ParentApprovalSection: View {
    @EnvironmentObject private var store: ChoreStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ready for approval")
                .font(.title3.bold())

            ForEach(store.approvalQueue) { chore in
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Text(chore.emoji)
                            .font(.system(size: 30))
                            .frame(width: 48, height: 48)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(chore.title)
                                .font(.headline)
                            Text("Done by \(store.memberName(chore.assignedTo))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if chore.rewardCents > 0 {
                            Text(money(chore.rewardCents))
                                .font(.subheadline.bold())
                        }
                    }

                    HStack {
                        Button("Send back") {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                                store.reopen(chore)
                            }
                        }
                        .buttonStyle(.bordered)

                        Button {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.68)) {
                                store.approve(chore)
                            }
                        } label: {
                            Label("Approve", systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .background(.background, in: RoundedRectangle(cornerRadius: 22))
                .transition(.move(edge: .trailing).combined(with: .scale(scale: 0.86)))
            }
        }
    }

    private func money(_ cents: Int) -> String {
        (Double(cents) / 100).formatted(.currency(code: "USD"))
    }
}

struct ParentChoreRow: View {
    @EnvironmentObject private var store: ChoreStore
    let chore: Chore

    var body: some View {
        HStack(spacing: 13) {
            Text(chore.emoji)
                .font(.system(size: 28))
                .frame(width: 48, height: 48)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                Text(chore.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text(chore.kind == .claimable ? "Anyone" : store.memberName(chore.assignedTo))

                    if let due = chore.dueDate {
                        Text("•")
                        Text(dueLabel(due))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if chore.rewardCents > 0 {
                Text(money(chore.rewardCents))
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
            }

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
    }

    private func dueLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func money(_ cents: Int) -> String {
        (Double(cents) / 100).formatted(.currency(code: "USD"))
    }
}

struct EmptyHomeCard: View {
    let emoji: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Text(emoji)
                .font(.system(size: 32))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct ChoreCard: View {
    @EnvironmentObject private var store: ChoreStore
    let chore: Chore
    @State private var feedbackTrigger = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Text(chore.emoji)
                    .font(.system(size: 30))
                    .frame(width: 50, height: 50)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 15))

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

                if chore.rewardCents > 0 {
                    Text(money(chore.rewardCents))
                        .font(.subheadline.bold())
                }
            }

            HStack(spacing: 8) {
                InfoChip(icon: "repeat", text: chore.recurrence.label)

                if let dueDate = chore.dueDate {
                    DueChip(date: dueDate)
                }

                if chore.status == .awaitingApproval {
                    InfoChip(icon: "clock.fill", text: "Waiting")
                }
            }

            if chore.assignedTo == store.activeMemberID && chore.status != .awaitingApproval {
                Button {
                    feedbackTrigger += 1
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.64)) {
                        store.complete(chore)
                    }
                } label: {
                    Label("Done", systemImage: "checkmark.circle.fill")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .sensoryFeedback(.success, trigger: feedbackTrigger)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 22))
    }

    private func money(_ cents: Int) -> String {
        (Double(cents) / 100).formatted(.currency(code: "USD"))
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
            .background(overdue ? Color.red.opacity(0.1) : Color.secondary.opacity(0.1), in: Capsule())
    }
}

struct ClaimableView: View {
    @EnvironmentObject private var store: ChoreStore
    @State private var feedbackTrigger = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Claim a chore")
                        .font(.largeTitle.bold())
                    Text("Grab something extra whenever you want.")
                        .foregroundStyle(.secondary)
                }

                if store.claimableChores.isEmpty {
                    EmptyHomeCard(
                        emoji: "✨",
                        title: "Nothing available",
                        subtitle: "There aren’t any open chores to claim."
                    )
                    .padding(.top, 12)
                } else {
                    ForEach(store.claimableChores) { chore in
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 12) {
                                Text(chore.emoji)
                                    .font(.system(size: 30))
                                    .frame(width: 50, height: 50)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 15))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(chore.title)
                                        .font(.headline)
                                    if !chore.detail.isEmpty {
                                        Text(chore.detail)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                if chore.rewardCents > 0 {
                                    Text(money(chore.rewardCents))
                                        .font(.subheadline.bold())
                                }
                            }

                            HStack(spacing: 8) {
                                InfoChip(icon: "repeat", text: chore.recurrence.label)
                                if let dueDate = chore.dueDate {
                                    DueChip(date: dueDate)
                                }
                            }

                            Button {
                                feedbackTrigger += 1
                                withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) {
                                    store.claim(chore)
                                }
                            } label: {
                                Label("Claim", systemImage: "hand.raised.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .background(.background, in: RoundedRectangle(cornerRadius: 22))
                        .transition(.move(edge: .trailing).combined(with: .scale(scale: 0.84)))
                    }
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
        .animation(.spring(response: 0.42, dampingFraction: 0.7), value: store.claimableChores)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func money(_ cents: Int) -> String {
        (Double(cents) / 100).formatted(.currency(code: "USD"))
    }
}

struct ActivityView: View {
    @EnvironmentObject private var store: ChoreStore

    var body: some View {
        List {
            if store.activeMemberCompletedChores.isEmpty {
                ContentUnavailableView(
                    "No history yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Finished chores will show up here.")
                )
            } else {
                ForEach(store.activeMemberCompletedChores) { chore in
                    HStack(spacing: 12) {
                        Text(chore.emoji)
                            .font(.title2)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(chore.title)
                                .font(.headline)
                            Text(chore.paidAt == nil && chore.rewardCents > 0 ? "Money owed" : "Complete")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if chore.rewardCents > 0 {
                            Text(money(chore.rewardCents))
                                .font(.subheadline.bold())
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("History")
    }

    private func money(_ cents: Int) -> String {
        (Double(cents) / 100).formatted(.currency(code: "USD"))
    }
}

struct ChoreEditorView: View {
    @EnvironmentObject private var store: ChoreStore
    @Environment(\.dismiss) private var dismiss

    var existingChore: Chore?

    @State private var emoji = "✨"
    @State private var title = ""
    @State private var detail = ""
    @State private var kind: ChoreKind = .assigned
    @State private var recurrence: Recurrence = .once
    @State private var assignee: UUID?
    @State private var requiresApproval = true
    @State private var rewardAmount: Double = 0
    @State private var hasDueDate = false
    @State private var dueDate = Date()

    private let emojiChoices = ["✨", "🧹", "🍽️", "🗑️", "🧺", "🛏️", "🐶", "🚿", "🌱", "🚗"]

    init(existingChore: Chore? = nil) {
        self.existingChore = existingChore
        _emoji = State(initialValue: existingChore?.emoji ?? "✨")
        _title = State(initialValue: existingChore?.title ?? "")
        _detail = State(initialValue: existingChore?.detail ?? "")
        _kind = State(initialValue: existingChore?.kind ?? .assigned)
        _recurrence = State(initialValue: existingChore?.recurrence ?? .once)
        _assignee = State(initialValue: existingChore?.assignedTo)
        _requiresApproval = State(initialValue: existingChore?.requiresApproval ?? true)
        _rewardAmount = State(initialValue: existingChore?.rewardAmount ?? 0)
        _hasDueDate = State(initialValue: existingChore?.dueDate != nil)
        _dueDate = State(initialValue: existingChore?.dueDate ?? Date())
    }

    var body: some View {
        Form {
            Section("Chore") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(emojiChoices, id: \.self) { choice in
                            Button {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) {
                                    emoji = choice
                                }
                            } label: {
                                Text(choice)
                                    .font(.system(size: 26))
                                    .frame(width: 48, height: 48)
                                    .background(
                                        emoji == choice ? Color.indigo.opacity(0.18) : Color.secondary.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 14)
                                    )
                                    .scaleEffect(emoji == choice ? 1.08 : 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack {
                    TextField("Emoji", text: $emoji)
                        .frame(width: 60)
                    TextField("What needs to be done?", text: $title)
                }

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

            Section("Money") {
                HStack {
                    Text("Reward")
                    Spacer()
                    TextField("$0.00", value: $rewardAmount, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 130)
                }

                Toggle("Require approval before money is owed", isOn: $requiresApproval)
            }

            if let existingChore {
                Section {
                    Button(role: .destructive) {
                        store.delete(existingChore)
                        dismiss()
                    } label: {
                        Label("Delete Chore", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(existingChore == nil ? "Add Chore" : "Edit Chore")
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
                .fontWeight(.semibold)
                .disabled(
                    title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    (kind == .assigned && assignee == nil)
                )
            }
        }
    }

    private func save() {
        let cents = max(0, Int((rewardAmount * 100).rounded()))

        if let existingChore {
            store.updateChore(
                existingChore,
                emoji: emoji,
                title: title,
                detail: detail,
                kind: kind,
                recurrence: recurrence,
                dueDate: hasDueDate ? dueDate : nil,
                assignee: assignee,
                requiresApproval: requiresApproval,
                rewardCents: cents
            )
        } else {
            store.addChore(
                emoji: emoji,
                title: title,
                detail: detail,
                kind: kind,
                recurrence: recurrence,
                dueDate: hasDueDate ? dueDate : nil,
                assignee: assignee,
                requiresApproval: requiresApproval,
                rewardCents: cents
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
