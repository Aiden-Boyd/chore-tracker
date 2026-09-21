import SwiftUI

struct SoftPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

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
            .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(store.activeMember.role == .parent ? "Home" : "Hey, \(store.activeMember.name)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))

                Text(store.activeMember.role == .parent
                     ? "Your household at a glance."
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
                        .frame(width: 50, height: 50)
                        .foregroundStyle(.white)
                        .background(.indigo, in: Circle())
                }
                .buttonStyle(SoftPressStyle())
                .sensoryFeedback(.selection, trigger: showingNewChore)
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
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.quaternary, in: Capsule())
            }

            if store.activeChores.isEmpty {
                EmptyHomeCard(
                    emoji: "🎉",
                    title: "Nothing active",
                    subtitle: "Tap + to add a chore."
                )
            } else {
                parentChoreSection(title: "Today", chores: parentTodayChores)
                parentChoreSection(title: "Upcoming", chores: parentUpcomingChores)
            }
        }
    }

    @ViewBuilder
    private var childHome: some View {
        ChildMoneyCard()

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your chores")
                    .font(.title3.bold())

                Spacer()

                if !store.myOpenChores.isEmpty {
                    Text("\(store.myOpenChores.count)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 28, minHeight: 28)
                        .background(.quaternary, in: Circle())
                }
            }

            if store.myOpenChores.isEmpty {
                EmptyHomeCard(
                    emoji: "🙌",
                    title: "You’re all caught up",
                    subtitle: "Check Claim if you want to grab something extra."
                )
            } else {
                childChoreSection(title: "Today", chores: childTodayChores)
                childChoreSection(title: "Upcoming", chores: childUpcomingChores)
            }
        }
    }

    private var parentTodayChores: [Chore] {
        store.activeChores.filter(isTodayChore)
    }

    private var parentUpcomingChores: [Chore] {
        store.activeChores.filter { !isTodayChore($0) }
    }

    private var childTodayChores: [Chore] {
        store.myOpenChores.filter(isTodayChore)
    }

    private var childUpcomingChores: [Chore] {
        store.myOpenChores.filter { !isTodayChore($0) }
    }

    private func isTodayChore(_ chore: Chore) -> Bool {
        guard let dueDate = chore.dueDate else { return true }
        return Calendar.current.isDateInToday(dueDate) || dueDate < Calendar.current.startOfDay(for: .now)
    }

    @ViewBuilder
    private func parentChoreSection(title: String, chores: [Chore]) -> some View {
        if !chores.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(chores) { chore in
                    SwipeRevealCard(
                        trailingTitle: "Delete",
                        trailingIcon: "trash.fill",
                        trailingTint: .red
                    ) {
                        store.delete(chore)
                    } content: {
                        NavigationLink {
                            EditChoreView(chore: chore)
                        } label: {
                            ParentChoreRow(chore: chore)
                        }
                        .buttonStyle(SoftPressStyle())
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func childChoreSection(title: String, chores: [Chore]) -> some View {
        if !chores.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(chores) { chore in
                    SwipeRevealCard(
                        leadingTitle: "Done",
                        leadingIcon: "checkmark.circle.fill",
                        leadingTint: .green,
                        leadingAction: {
                            store.complete(chore)
                        }
                    ) {
                        ChoreCard(chore: chore)
                    }
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

struct SwipeRevealCard<Content: View>: View {
    var leadingTitle: String? = nil
    var leadingIcon: String? = nil
    var leadingTint: Color = .green
    var leadingAction: (() -> Void)? = nil

    var trailingTitle: String? = nil
    var trailingIcon: String? = nil
    var trailingTint: Color = .red
    var trailingAction: (() -> Void)? = nil

    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var restingOffset: CGFloat = 0
    @State private var dragDirection: DragDirection?

    private enum DragDirection {
        case horizontal
        case vertical
    }

    private let actionWidth: CGFloat = 84

    init(
        leadingTitle: String? = nil,
        leadingIcon: String? = nil,
        leadingTint: Color = .green,
        leadingAction: (() -> Void)? = nil,
        trailingTitle: String? = nil,
        trailingIcon: String? = nil,
        trailingTint: Color = .red,
        trailingAction: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.leadingTitle = leadingTitle
        self.leadingIcon = leadingIcon
        self.leadingTint = leadingTint
        self.leadingAction = leadingAction
        self.trailingTitle = trailingTitle
        self.trailingIcon = trailingIcon
        self.trailingTint = trailingTint
        self.trailingAction = trailingAction
        self.content = content
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                if let leadingAction {
                    swipeButton(
                        title: leadingTitle ?? "Action",
                        icon: leadingIcon ?? "checkmark",
                        tint: leadingTint
                    ) {
                        leadingAction()
                        close()
                    }
                    .frame(width: actionWidth)
                }

                Spacer(minLength: 0)

                if let trailingAction {
                    swipeButton(
                        title: trailingTitle ?? "Action",
                        icon: trailingIcon ?? "trash",
                        tint: trailingTint
                    ) {
                        trailingAction()
                        close()
                    }
                    .frame(width: actionWidth)
                }
            }

            content()
                .offset(x: offset)
                .contentShape(Rectangle())
                .overlay {
                    if offset != 0 {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                close()
                            }
                    }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 18)
                        .onChanged { value in
                            let horizontalDistance = abs(value.translation.width)
                            let verticalDistance = abs(value.translation.height)

                            if dragDirection == nil {
                                guard max(horizontalDistance, verticalDistance) >= 18 else { return }
                                dragDirection = horizontalDistance > verticalDistance * 1.35
                                    ? .horizontal
                                    : .vertical
                            }

                            guard dragDirection == .horizontal else { return }

                            let proposed = restingOffset + value.translation.width
                            let minOffset = trailingAction == nil ? 0 : -actionWidth
                            let maxOffset = leadingAction == nil ? 0 : actionWidth
                            offset = min(max(proposed, minOffset), maxOffset)
                        }
                        .onEnded { value in
                            defer { dragDirection = nil }

                            guard dragDirection == .horizontal else {
                                if restingOffset == 0 {
                                    offset = 0
                                }
                                return
                            }

                            let threshold = actionWidth * 0.5
                            let projectedOffset = restingOffset + value.predictedEndTranslation.width

                            withAnimation(.easeOut(duration: 0.18)) {
                                if offset > threshold,
                                   projectedOffset > 0,
                                   leadingAction != nil {
                                    offset = actionWidth
                                    restingOffset = actionWidth
                                } else if offset < -threshold,
                                          projectedOffset < 0,
                                          trailingAction != nil {
                                    offset = -actionWidth
                                    restingOffset = -actionWidth
                                } else {
                                    offset = 0
                                    restingOffset = 0
                                }
                            }
                        }
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func swipeButton(
        title: String,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.title3.bold())
                Text(title)
                    .font(.caption.bold())
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(tint)
        }
        .buttonStyle(.plain)
    }

    private func close() {
        withAnimation(.easeOut(duration: 0.18)) {
            offset = 0
            restingOffset = 0
        }
    }
}

struct MoneyOwedCard: View {
    @EnvironmentObject private var store: ChoreStore
    @State private var paidFeedback = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Label("Money owed", systemImage: "dollarsign.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(money(store.totalMoneyOwedCents))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                        .animation(.snappy, value: store.totalMoneyOwedCents)
                }

                Spacer()

                Text("💵")
                    .font(.system(size: 42))
                    .symbolEffect(.bounce, value: paidFeedback)
            }

            if store.totalMoneyOwedCents == 0 {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Everyone is paid up.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Divider()

                ForEach(store.children) { child in
                    let owed = store.moneyOwedCents(to: child.id)
                    if owed > 0 {
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
                                    .font(.headline)
                                Text(money(owed))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                paidFeedback += 1
                                store.markPaid(to: child.id)
                            } label: {
                                Text("Mark paid")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(.quaternary, in: Capsule())
                            }
                            .buttonStyle(SoftPressStyle())
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(.quaternary, lineWidth: 1)
        )
        .sensoryFeedback(.success, trigger: paidFeedback)
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
                .font(.system(size: 40))
                .frame(width: 58, height: 58)
                .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))

            VStack(alignment: .leading, spacing: 3) {
                Text("Money owed to you")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text((Double(store.activeMemberMoneyOwedCents) / 100).formatted(.currency(code: "USD")))
                    .font(.title2.bold())
                    .contentTransition(.numericText())
            }

            Spacer()
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(.quaternary, lineWidth: 1)
        )
    }
}

struct ParentApprovalSection: View {
    @EnvironmentObject private var store: ChoreStore
    @State private var approvalFeedback = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ready for approval")
                    .font(.title3.bold())

                Spacer()

                Text("\(store.approvalQueue.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                    .frame(width: 28, height: 28)
                    .background(.orange.opacity(0.12), in: Circle())
            }

            ForEach(store.approvalQueue) { chore in
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        Text(chore.emoji)
                            .font(.system(size: 30))
                            .frame(width: 52, height: 52)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))

                        VStack(alignment: .leading, spacing: 3) {
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

                    HStack(spacing: 10) {
                        Button {
                            store.reopen(chore)
                        } label: {
                            Label("Send back", systemImage: "arrow.uturn.backward")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(SoftPressStyle())

                        Button {
                            approvalFeedback += 1
                            store.approve(chore)
                        } label: {
                            Label("Approve", systemImage: "checkmark")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(.indigo, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(SoftPressStyle())
                    }
                }
                .padding(16)
                .background(.background, in: RoundedRectangle(cornerRadius: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(.orange.opacity(0.22), lineWidth: 1)
                )
            }
        }
        .sensoryFeedback(.success, trigger: approvalFeedback)
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
                .font(.system(size: 29))
                .frame(width: 50, height: 50)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 15))

            VStack(alignment: .leading, spacing: 5) {
                Text(chore.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Label(
                        chore.kind == .claimable ? "Anyone" : store.memberName(chore.assignedTo),
                        systemImage: chore.kind == .claimable ? "person.2.fill" : "person.fill"
                    )

                    if let due = chore.dueDate {
                        Text("•")
                        Text(dueLabel(due))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 7) {
                if chore.rewardCents > 0 {
                    Text(money(chore.rewardCents))
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.quaternary, lineWidth: 1)
        )
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
                .font(.system(size: 34))
                .frame(width: 54, height: 54)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 17))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.quaternary, lineWidth: 1)
        )
    }
}

struct ChoreCard: View {
    @EnvironmentObject private var store: ChoreStore
    let chore: Chore

    @State private var feedbackTrigger = 0
    @State private var showConfirmation = false

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Text(chore.emoji)
                        .font(.system(size: 31))
                        .frame(width: 54, height: 54)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))

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
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(.green.opacity(0.1), in: Capsule())
                    }
                }

                HStack(spacing: 8) {
                    if chore.recurrence != .once {
                        InfoChip(icon: "repeat", text: chore.recurrence.label)
                    }

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
                        withAnimation(.easeOut(duration: 0.16)) {
                            showConfirmation = true
                        }
                        store.complete(chore)
                    } label: {
                        Label("Done", systemImage: "checkmark.circle.fill")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.indigo, in: RoundedRectangle(cornerRadius: 15))
                    }
                    .buttonStyle(SoftPressStyle())
                    .sensoryFeedback(.success, trigger: feedbackTrigger)
                }
            }
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 23))
            .overlay(
                RoundedRectangle(cornerRadius: 23)
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
            )

            if showConfirmation {
                RoundedRectangle(cornerRadius: 23)
                    .fill(.ultraThinMaterial)

                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce, value: showConfirmation)

                    Text(chore.requiresApproval ? "Sent for approval" : "Completed")
                        .font(.headline)
                }
                .transition(.opacity)
            }
        }
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
            .font(.caption.weight(.medium))
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
            .font(.caption.weight(.medium))
            .foregroundStyle(overdue ? .red : .secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(overdue ? Color.red.opacity(0.1) : Color.secondary.opacity(0.1), in: Capsule())
    }
}

struct ClaimableView: View {
    @EnvironmentObject private var store: ChoreStore
    @State private var feedbackTrigger = 0
    @State private var claimingID: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Claim a chore")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("Pick something extra and earn a little more.")
                        .foregroundStyle(.secondary)
                }

                if store.claimableChores.isEmpty {
                    EmptyHomeCard(
                        emoji: "✨",
                        title: "Nothing available",
                        subtitle: "There aren’t any open chores to claim."
                    )
                    .padding(.top, 8)
                } else {
                    ForEach(store.claimableChores) { chore in
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 12) {
                                Text(chore.emoji)
                                    .font(.system(size: 31))
                                    .frame(width: 54, height: 54)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))

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
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 6)
                                        .background(.green.opacity(0.1), in: Capsule())
                                }
                            }

                            HStack(spacing: 8) {
                                if chore.recurrence != .once {
                                    InfoChip(icon: "repeat", text: chore.recurrence.label)
                                }

                                if let dueDate = chore.dueDate {
                                    DueChip(date: dueDate)
                                }
                            }

                            Button {
                                guard claimingID == nil else { return }
                                claimingID = chore.id
                                feedbackTrigger += 1
                                store.claim(chore)

                                Task {
                                    try? await Task.sleep(for: .milliseconds(180))
                                    claimingID = nil
                                }
                            } label: {
                                HStack {
                                    Spacer()
                                    Image(systemName: claimingID == chore.id ? "checkmark.circle.fill" : "hand.raised.fill")
                                    Text(claimingID == chore.id ? "Claimed!" : "Claim")
                                    Spacer()
                                }
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.vertical, 12)
                                .background(claimingID == chore.id ? Color.green : Color.indigo, in: RoundedRectangle(cornerRadius: 15))
                                .animation(.snappy, value: claimingID)
                            }
                            .buttonStyle(SoftPressStyle())
                        }
                        .padding(16)
                        .background(.background, in: RoundedRectangle(cornerRadius: 23))
                        .overlay(
                            RoundedRectangle(cornerRadius: 23)
                                .stroke(claimingID == chore.id ? Color.green.opacity(0.35) : Color.secondary.opacity(0.1), lineWidth: 1)
                        )
                    }
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .sensoryFeedback(.success, trigger: feedbackTrigger)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func money(_ cents: Int) -> String {
        (Double(cents) / 100).formatted(.currency(code: "USD"))
    }
}

struct HistoryView: View {
    @EnvironmentObject private var store: ChoreStore
    @State private var selectedDate = Date()
    @State private var dateFeedback = 0

    private var choresForDay: [Chore] {
        if store.activeMember.role == .parent {
            return store.completedChores(on: selectedDate)
        }
        return store.completedChores(on: selectedDate, for: store.activeMemberID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("History")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                        Text("See what got done each day.")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !Calendar.current.isDateInToday(selectedDate) {
                        Button("Today") {
                            selectedDate = Date()
                            dateFeedback += 1
                        }
                        .font(.subheadline.bold())
                        .buttonStyle(.bordered)
                    }
                }

                DatePicker(
                    "History date",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(8)
                .background(.background, in: RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(.quaternary, lineWidth: 1)
                )
                .onChange(of: selectedDate) { _, _ in
                    dateFeedback += 1
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                                .font(.title3.bold())
                            Text(selectedDate.formatted(.dateTime.month(.wide).day()))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Label("\(choresForDay.count)", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(choresForDay.isEmpty ? Color.secondary : Color.green)
                    }

                    if choresForDay.isEmpty {
                        EmptyHomeCard(
                            emoji: "📅",
                            title: "No completed chores",
                            subtitle: store.activeMember.role == .parent
                                ? "Nothing was completed by the family on this day."
                                : "You didn’t complete any chores on this day."
                        )
                    } else {
                        ForEach(choresForDay) { chore in
                            HStack(spacing: 12) {
                                Text(chore.emoji)
                                    .font(.system(size: 28))
                                    .frame(width: 48, height: 48)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(chore.title)
                                        .font(.headline)

                                    if store.activeMember.role == .parent {
                                        Text(store.memberName(chore.assignedTo))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text(chore.paidAt == nil && chore.rewardCents > 0 ? "Money owed" : "Complete")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                if chore.rewardCents > 0 {
                                    Text(money(chore.rewardCents))
                                        .font(.subheadline.bold())
                                }
                            }
                            .padding(15)
                            .background(.background, in: RoundedRectangle(cornerRadius: 18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(.quaternary, lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: dateFeedback)
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
    @State private var customWeekdays: Set<Int> = []
    @State private var weekInterval = 1
    @State private var saveFeedback = 0

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
        _customWeekdays = State(initialValue: Set(existingChore?.customWeekdays ?? []))
        _weekInterval = State(initialValue: max(1, existingChore?.weekInterval ?? 1))
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (kind == .claimable || assignee != nil) &&
        (recurrence != .custom || !customWeekdays.isEmpty)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                preview

                editorCard(title: "Chore", systemImage: "sparkles") {
                    HStack(spacing: 12) {
                        TextField("😀", text: $emoji)
                            .font(.system(size: 32))
                            .multilineTextAlignment(.center)
                            .frame(width: 58, height: 58)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 17))

                        VStack(spacing: 10) {
                            TextField("What needs to be done?", text: $title)
                                .font(.headline)
                                .textInputAutocapitalization(.sentences)

                            Divider()

                            TextField("Notes or instructions", text: $detail, axis: .vertical)
                                .font(.subheadline)
                                .lineLimit(2...4)
                        }
                    }
                }

                editorCard(title: "Who", systemImage: "person.2.fill") {
                    HStack(spacing: 8) {
                        choiceButton(
                            title: "Assigned",
                            icon: "person.fill",
                            selected: kind == .assigned
                        ) {
                            kind = .assigned
                        }

                        choiceButton(
                            title: "Anyone",
                            icon: "hand.raised.fill",
                            selected: kind == .claimable
                        ) {
                            kind = .claimable
                        }
                    }

                    if kind == .assigned {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(store.children) { child in
                                    Button {
                                        assignee = child.id
                                    } label: {
                                        HStack(spacing: 7) {
                                            Circle()
                                                .fill(.indigo.opacity(0.12))
                                                .frame(width: 28, height: 28)
                                                .overlay(
                                                    Text(String(child.name.prefix(1)).uppercased())
                                                        .font(.caption.bold())
                                                        .foregroundStyle(.indigo)
                                                )

                                            Text(child.name)
                                                .font(.subheadline.weight(.semibold))
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(
                                            assignee == child.id ? Color.indigo.opacity(0.14) : Color.secondary.opacity(0.08),
                                            in: Capsule()
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(assignee == child.id ? Color.indigo.opacity(0.4) : Color.clear, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(SoftPressStyle())
                                }
                            }
                        }
                    }
                }

                editorCard(title: "Schedule", systemImage: "calendar") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Recurrence.allCases) { option in
                                Button {
                                    recurrence = option
                                } label: {
                                    Text(option.label)
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 9)
                                        .foregroundStyle(recurrence == option ? Color.white : Color.primary)
                                        .background(
                                            recurrence == option ? Color.indigo : Color.secondary.opacity(0.09),
                                            in: Capsule()
                                        )
                                }
                                .buttonStyle(SoftPressStyle())
                            }
                        }
                    }

                    if recurrence == .custom {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Repeat on")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            HStack(spacing: 7) {
                                ForEach(Array(zip([1, 2, 3, 4, 5, 6, 7], ["S", "M", "T", "W", "T", "F", "S"])), id: \.0) { weekday, label in
                                    Button {
                                        if customWeekdays.contains(weekday) {
                                            customWeekdays.remove(weekday)
                                        } else {
                                            customWeekdays.insert(weekday)
                                        }
                                    } label: {
                                        Text(label)
                                            .font(.subheadline.bold())
                                            .frame(width: 36, height: 36)
                                            .foregroundStyle(customWeekdays.contains(weekday) ? Color.white : Color.primary)
                                            .background(
                                                customWeekdays.contains(weekday) ? Color.indigo : Color.secondary.opacity(0.1),
                                                in: Circle()
                                            )
                                    }
                                    .buttonStyle(SoftPressStyle())
                                }
                            }

                            Stepper(value: $weekInterval, in: 1...8) {
                                HStack {
                                    Text("Repeat")
                                    Spacer()
                                    Text(weekInterval == 1 ? "Every week" : "Every \(weekInterval) weeks")
                                        .foregroundStyle(.secondary)
                                }
                                .font(.subheadline)
                            }

                            if customWeekdays.isEmpty {
                                Label("Choose at least one day", systemImage: "exclamationmark.circle")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .transition(.opacity)
                    }

                    Toggle(isOn: $hasDueDate.animation(.easeOut(duration: 0.16))) {
                        Label("Set due date & time", systemImage: "clock")
                    }

                    if hasDueDate {
                        VStack(spacing: 10) {
                            DatePicker("Date", selection: $dueDate, displayedComponents: .date)
                                .datePickerStyle(.compact)

                            DatePicker("Time", selection: $dueDate, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact)
                        }
                        .transition(.opacity)
                    }
                }

                editorCard(title: "Reward", systemImage: "dollarsign.circle.fill") {
                    HStack(spacing: 8) {
                        ForEach([0.0, 1.0, 2.0, 5.0], id: \.self) { amount in
                            Button {
                                rewardAmount = amount
                            } label: {
                                Text(amount == 0 ? "None" : amount.formatted(.currency(code: "USD")))
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .foregroundStyle(rewardAmount == amount ? .white : .primary)
                                    .background(
                                        rewardAmount == amount ? Color.indigo : Color.secondary.opacity(0.09),
                                        in: RoundedRectangle(cornerRadius: 13)
                                    )
                            }
                            .buttonStyle(SoftPressStyle())
                        }
                    }

                    HStack {
                        Text("Custom")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        TextField("$0.00", value: $rewardAmount, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 140)
                    }

                    Toggle("Require parent approval", isOn: $requiresApproval)
                }

                if let existingChore {
                    Button(role: .destructive) {
                        store.delete(existingChore)
                        dismiss()
                    } label: {
                        Label("Delete chore", systemImage: "trash")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 15))
                    }
                    .buttonStyle(SoftPressStyle())
                }
            }
            .padding()
            .padding(.bottom, 90)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(existingChore == nil ? "New Chore" : "Edit Chore")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()

                Button {
                    saveFeedback += 1
                    save()
                    dismiss()
                } label: {
                    Text(existingChore == nil ? "Add Chore" : "Save Changes")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canSave ? Color.indigo : Color.secondary.opacity(0.45), in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(SoftPressStyle())
                .disabled(!canSave)
                .padding()
                .background(.bar)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .sensoryFeedback(.success, trigger: saveFeedback)
    }

    private var preview: some View {
        HStack(spacing: 14) {
            Text(emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "✨" : emoji)
                .font(.system(size: 34))
                .frame(width: 62, height: 62)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 19))

            VStack(alignment: .leading, spacing: 4) {
                Text(title.isEmpty ? "Your chore" : title)
                    .font(.title3.bold())
                    .foregroundStyle(title.isEmpty ? .secondary : .primary)

                HStack(spacing: 6) {
                    Text(kind == .claimable ? "Anyone can claim" : assigneeName)
                    if rewardAmount > 0 {
                        Text("•")
                        Text(rewardAmount.formatted(.currency(code: "USD")))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(.indigo.opacity(0.15), lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.16), value: title)
        .animation(.easeOut(duration: 0.16), value: kind)
        .animation(.easeOut(duration: 0.16), value: assignee)
        .animation(.easeOut(duration: 0.16), value: rewardAmount)
    }

    private var assigneeName: String {
        guard let assignee else { return "Choose someone" }
        return store.memberName(assignee)
    }

    @ViewBuilder
    private func editorCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            content()
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(.quaternary, lineWidth: 1)
        )
    }

    private func choiceButton(
        title: String,
        icon: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(selected ? Color.indigo : Color.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(SoftPressStyle())
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
                rewardCents: cents,
                customWeekdays: recurrence == .custom ? Array(customWeekdays).sorted() : nil,
                weekInterval: recurrence == .custom ? weekInterval : nil
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
                rewardCents: cents,
                customWeekdays: recurrence == .custom ? Array(customWeekdays).sorted() : nil,
                weekInterval: recurrence == .custom ? weekInterval : nil
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
