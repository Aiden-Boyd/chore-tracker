import Foundation

@MainActor
final class ChoreStore: ObservableObject {
    @Published var members: [FamilyMember] { didSet { save() } }
    @Published var chores: [Chore] { didSet { save() } }
    @Published var activeMemberID: UUID { didSet { save() } }
    @Published private(set) var undoMessage: String?

    private var undoSnapshot: [Chore]?
    private var undoToken: UUID?
    private var undoTask: Task<Void, Never>?

    private static let storageKey = "chore-tracker.snapshot.v3"

    private struct Snapshot: Codable {
        var members: [FamilyMember]
        var chores: [Chore]
        var activeMemberID: UUID
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
           !snapshot.members.isEmpty {
            members = snapshot.members
            chores = snapshot.chores
            activeMemberID = snapshot.members.contains(where: { $0.id == snapshot.activeMemberID })
                ? snapshot.activeMemberID
                : snapshot.members[0].id
            return
        }

        let mom = FamilyMember(name: "Mom", role: .parent)
        let aiden = FamilyMember(name: "Aiden", role: .child)
        let sibling = FamilyMember(name: "Sam", role: .child)

        members = [mom, aiden, sibling]
        activeMemberID = mom.id
        chores = [
            Chore(
                emoji: "🍽️",
                title: "Unload dishwasher",
                detail: "Put everything away and clear the rack.",
                kind: .assigned,
                recurrence: .daily,
                dueDate: Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: .now),
                assignedTo: aiden.id,
                requiresApproval: false,
                rewardCents: 100
            ),
            Chore(
                emoji: "🗑️",
                title: "Take trash out",
                detail: "Kitchen and upstairs trash.",
                kind: .assigned,
                recurrence: .weekly,
                dueDate: Calendar.current.date(byAdding: .day, value: 1, to: .now),
                assignedTo: sibling.id,
                requiresApproval: true,
                rewardCents: 200
            ),
            Chore(
                emoji: "🧹",
                title: "Vacuum living room",
                detail: "Available to anyone.",
                kind: .claimable,
                recurrence: .weekly,
                requiresApproval: true,
                rewardCents: 300
            ),
            Chore(
                emoji: "✨",
                title: "Wipe kitchen counters",
                kind: .claimable,
                recurrence: .daily,
                requiresApproval: false,
                rewardCents: 100
            )
        ]
        save()
    }

    var activeMember: FamilyMember {
        members.first(where: { $0.id == activeMemberID }) ?? members[0]
    }

    var children: [FamilyMember] {
        members.filter { $0.role == .child }
    }

    var myOpenChores: [Chore] {
        chores
            .filter {
                $0.assignedTo == activeMemberID &&
                $0.status != .completed &&
                isAvailable($0)
            }
            .sorted(by: choreSort)
    }

    var claimableChores: [Chore] {
        chores
            .filter {
                $0.kind == .claimable &&
                $0.status == .open &&
                isAvailable($0)
            }
            .sorted(by: choreSort)
    }

    var approvalQueue: [Chore] {
        chores.filter { $0.status == .awaitingApproval }
    }

    var activeChores: [Chore] {
        chores
            .filter { $0.status != .completed && isAvailable($0) }
            .sorted(by: choreSort)
    }

    var completedChores: [Chore] {
        chores
            .filter { $0.status == .completed }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    var activeMemberCompletedChores: [Chore] {
        completedChores.filter {
            $0.assignedTo == activeMemberID || $0.claimedBy == activeMemberID
        }
    }

    var totalMoneyOwedCents: Int {
        chores
            .filter { $0.status == .completed && $0.paidAt == nil }
            .reduce(0) { $0 + $1.rewardCents }
    }

    func moneyOwedCents(to memberID: UUID) -> Int {
        chores
            .filter {
                $0.status == .completed &&
                $0.paidAt == nil &&
                ($0.assignedTo == memberID || $0.claimedBy == memberID)
            }
            .reduce(0) { $0 + $1.rewardCents }
    }

    var activeMemberMoneyOwedCents: Int {
        moneyOwedCents(to: activeMemberID)
    }

    func completedChores(on date: Date, for memberID: UUID? = nil) -> [Chore] {
        let calendar = Calendar.current
        return completedChores.filter { chore in
            guard let completedAt = chore.completedAt,
                  calendar.isDate(completedAt, inSameDayAs: date) else { return false }

            if let memberID {
                return chore.assignedTo == memberID || chore.claimedBy == memberID
            }
            return true
        }
    }

    func memberName(_ id: UUID?) -> String {
        guard let id else { return "Anyone" }
        return members.first(where: { $0.id == id })?.name ?? "Unknown"
    }

    func claim(_ chore: Chore) {
        guard let index = chores.firstIndex(where: { $0.id == chore.id }),
              chores[index].kind == .claimable,
              chores[index].status == .open,
              isAvailable(chores[index]) else { return }

        recordUndo("Chore claimed")
        chores[index].claimedBy = activeMemberID
        chores[index].assignedTo = activeMemberID
        chores[index].status = .claimed
    }

    func complete(_ chore: Chore) {
        guard let index = chores.firstIndex(where: { $0.id == chore.id }) else { return }

        recordUndo(chores[index].requiresApproval ? "Sent for approval" : "Chore completed")
        let completedCopy = chores[index]
        if chores[index].requiresApproval {
            chores[index].status = .awaitingApproval
        } else {
            chores[index].status = .completed
            chores[index].completedAt = .now
            createNextOccurrenceIfNeeded(from: completedCopy)
        }
    }

    func approve(_ chore: Chore) {
        guard let index = chores.firstIndex(where: { $0.id == chore.id }) else { return }

        recordUndo("Chore approved")
        let completedCopy = chores[index]
        chores[index].status = .completed
        chores[index].completedAt = .now
        createNextOccurrenceIfNeeded(from: completedCopy)
    }

    func reopen(_ chore: Chore) {
        guard let index = chores.firstIndex(where: { $0.id == chore.id }) else { return }
        recordUndo("Chore sent back")
        chores[index].status = .claimed
    }

    func markPaid(to memberID: UUID) {
        let hasUnpaid = chores.contains {
            $0.status == .completed &&
            $0.paidAt == nil &&
            ($0.assignedTo == memberID || $0.claimedBy == memberID)
        }
        guard hasUnpaid else { return }

        recordUndo("Marked paid")

        for index in chores.indices where
            chores[index].status == .completed &&
            chores[index].paidAt == nil &&
            (chores[index].assignedTo == memberID || chores[index].claimedBy == memberID) {
            chores[index].paidAt = .now
        }
    }

    func addChore(
        emoji: String,
        title: String,
        detail: String,
        kind: ChoreKind,
        recurrence: Recurrence,
        dueDate: Date?,
        assignee: UUID?,
        requiresApproval: Bool,
        rewardCents: Int
    ) {
        recordUndo("Chore added")

        let chore = Chore(
            emoji: normalizedEmoji(emoji),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kind,
            recurrence: recurrence,
            dueDate: dueDate,
            assignedTo: kind == .assigned ? assignee : nil,
            requiresApproval: requiresApproval,
            rewardCents: rewardCents
        )
        chores.insert(chore, at: 0)
    }

    func updateChore(
        _ chore: Chore,
        emoji: String,
        title: String,
        detail: String,
        kind: ChoreKind,
        recurrence: Recurrence,
        dueDate: Date?,
        assignee: UUID?,
        requiresApproval: Bool,
        rewardCents: Int
    ) {
        guard let index = chores.firstIndex(where: { $0.id == chore.id }) else { return }
        recordUndo("Changes saved")
        chores[index].emoji = normalizedEmoji(emoji)
        chores[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        chores[index].detail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        chores[index].kind = kind
        chores[index].recurrence = recurrence
        chores[index].dueDate = dueDate
        chores[index].assignedTo = kind == .assigned ? assignee : nil
        chores[index].claimedBy = kind == .claimable ? nil : chores[index].claimedBy
        chores[index].requiresApproval = requiresApproval
        chores[index].rewardCents = rewardCents
    }

    func delete(_ chore: Chore) {
        guard chores.contains(where: { $0.id == chore.id }) else { return }
        recordUndo("Chore deleted")
        chores.removeAll { $0.id == chore.id }
    }

    func undoLastAction() {
        guard let snapshot = undoSnapshot else { return }

        undoTask?.cancel()
        chores = snapshot
        undoSnapshot = nil
        undoMessage = nil
        undoToken = nil
    }

    func dismissUndo() {
        undoTask?.cancel()
        undoSnapshot = nil
        undoMessage = nil
        undoToken = nil
    }

    private func recordUndo(_ message: String) {
        undoTask?.cancel()

        let token = UUID()
        undoSnapshot = chores
        undoMessage = message
        undoToken = token

        undoTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, let self, self.undoToken == token else { return }

            self.undoSnapshot = nil
            self.undoMessage = nil
            self.undoToken = nil
        }
    }

    private func isAvailable(_ chore: Chore) -> Bool {
        guard let availableFrom = chore.availableFrom else { return true }
        return availableFrom <= .now
    }

    private func normalizedEmoji(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "✨" : value
    }

    private func save() {
        let snapshot = Snapshot(members: members, chores: chores, activeMemberID: activeMemberID)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func createNextOccurrenceIfNeeded(from chore: Chore) {
        guard chore.recurrence != .once else { return }

        let base = chore.dueDate ?? .now
        guard let nextDate = nextDueDate(after: base, recurrence: chore.recurrence) else { return }

        let nextAvailable = Calendar.current.startOfDay(for: nextDate)

        let next = Chore(
            emoji: chore.emoji,
            title: chore.title,
            detail: chore.detail,
            kind: chore.kind,
            recurrence: chore.recurrence,
            dueDate: nextDate,
            availableFrom: nextAvailable,
            assignedTo: chore.kind == .assigned ? chore.assignedTo : nil,
            claimedBy: nil,
            status: .open,
            requiresApproval: chore.requiresApproval,
            rewardCents: chore.rewardCents
        )
        chores.insert(next, at: 0)
    }

    private func nextDueDate(after date: Date, recurrence: Recurrence) -> Date? {
        let calendar = Calendar.current

        switch recurrence {
        case .once:
            return nil
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        case .weekdays:
            var candidate = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            while calendar.isDateInWeekend(candidate) {
                candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
            }
            return candidate
        }
    }

    private func choreSort(_ lhs: Chore, _ rhs: Chore) -> Bool {
        switch (lhs.dueDate, rhs.dueDate) {
        case let (l?, r?): return l < r
        case (_?, nil): return true
        case (nil, _?): return false
        default: return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}
