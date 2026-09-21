import Foundation

@MainActor
final class ChoreStore: ObservableObject {
    @Published var members: [FamilyMember] { didSet { save() } }
    @Published var chores: [Chore] { didSet { save() } }
    @Published var activeMemberID: UUID { didSet { save() } }

    private static let storageKey = "chore-tracker.snapshot.v1"

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
        activeMemberID = aiden.id
        chores = [
            Chore(
                title: "Unload dishwasher",
                detail: "Put everything away and clear the rack.",
                kind: .assigned,
                recurrence: .daily,
                dueDate: Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: .now),
                assignedTo: aiden.id,
                requiresApproval: false,
                points: 5
            ),
            Chore(
                title: "Take trash out",
                detail: "Kitchen and upstairs trash.",
                kind: .assigned,
                recurrence: .weekly,
                dueDate: Calendar.current.date(byAdding: .day, value: 1, to: .now),
                assignedTo: sibling.id,
                requiresApproval: true,
                points: 10
            ),
            Chore(
                title: "Vacuum living room",
                detail: "Available to anyone.",
                kind: .claimable,
                recurrence: .weekly,
                requiresApproval: true,
                points: 15
            ),
            Chore(
                title: "Wipe kitchen counters",
                kind: .claimable,
                recurrence: .daily,
                requiresApproval: false,
                points: 5
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
            .filter { $0.assignedTo == activeMemberID && $0.status != .completed }
            .sorted(by: choreSort)
    }

    var claimableChores: [Chore] {
        chores
            .filter { $0.kind == .claimable && $0.status == .open }
            .sorted(by: choreSort)
    }

    var approvalQueue: [Chore] {
        chores.filter { $0.status == .awaitingApproval }
    }

    var completedChores: [Chore] {
        chores.filter { $0.status == .completed }.reversed()
    }

    var activeMemberCompletedChores: [Chore] {
        chores.filter {
            $0.status == .completed &&
            ($0.assignedTo == activeMemberID || $0.claimedBy == activeMemberID)
        }.reversed()
    }

    var activeMemberPoints: Int {
        activeMemberCompletedChores.reduce(0) { $0 + $1.points }
    }

    var overdueCount: Int {
        chores.filter { chore in
            guard chore.status != .completed, let due = chore.dueDate else { return false }
            return due < .now && !Calendar.current.isDateInToday(due)
        }.count
    }

    func memberName(_ id: UUID?) -> String {
        guard let id else { return "Anyone" }
        return members.first(where: { $0.id == id })?.name ?? "Unknown"
    }

    func claim(_ chore: Chore) {
        guard let index = chores.firstIndex(where: { $0.id == chore.id }),
              chores[index].kind == .claimable,
              chores[index].status == .open else { return }

        chores[index].claimedBy = activeMemberID
        chores[index].assignedTo = activeMemberID
        chores[index].status = .claimed
    }

    func complete(_ chore: Chore) {
        guard let index = chores.firstIndex(where: { $0.id == chore.id }) else { return }

        let completedCopy = chores[index]
        if chores[index].requiresApproval {
            chores[index].status = .awaitingApproval
        } else {
            chores[index].status = .completed
            createNextOccurrenceIfNeeded(from: completedCopy)
        }
    }

    func approve(_ chore: Chore) {
        guard let index = chores.firstIndex(where: { $0.id == chore.id }) else { return }

        let completedCopy = chores[index]
        chores[index].status = .completed
        createNextOccurrenceIfNeeded(from: completedCopy)
    }

    func reopen(_ chore: Chore) {
        guard let index = chores.firstIndex(where: { $0.id == chore.id }) else { return }
        chores[index].status = .claimed
    }

    func addChore(
        title: String,
        detail: String,
        kind: ChoreKind,
        recurrence: Recurrence,
        dueDate: Date?,
        assignee: UUID?,
        requiresApproval: Bool,
        points: Int
    ) {
        let chore = Chore(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kind,
            recurrence: recurrence,
            dueDate: dueDate,
            assignedTo: kind == .assigned ? assignee : nil,
            requiresApproval: requiresApproval,
            points: points
        )
        chores.insert(chore, at: 0)
    }

    func updateChore(
        _ chore: Chore,
        title: String,
        detail: String,
        kind: ChoreKind,
        recurrence: Recurrence,
        dueDate: Date?,
        assignee: UUID?,
        requiresApproval: Bool,
        points: Int
    ) {
        guard let index = chores.firstIndex(where: { $0.id == chore.id }) else { return }
        chores[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        chores[index].detail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        chores[index].kind = kind
        chores[index].recurrence = recurrence
        chores[index].dueDate = dueDate
        chores[index].assignedTo = kind == .assigned ? assignee : nil
        chores[index].claimedBy = kind == .claimable ? nil : chores[index].claimedBy
        chores[index].requiresApproval = requiresApproval
        chores[index].points = points
    }

    func delete(_ chore: Chore) {
        chores.removeAll { $0.id == chore.id }
    }

    private func save() {
        let snapshot = Snapshot(members: members, chores: chores, activeMemberID: activeMemberID)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func createNextOccurrenceIfNeeded(from chore: Chore) {
        guard chore.recurrence != .once else { return }

        let next = Chore(
            title: chore.title,
            detail: chore.detail,
            kind: chore.kind,
            recurrence: chore.recurrence,
            dueDate: nextDueDate(after: chore.dueDate ?? .now, recurrence: chore.recurrence),
            assignedTo: chore.kind == .assigned ? chore.assignedTo : nil,
            claimedBy: nil,
            status: .open,
            requiresApproval: chore.requiresApproval,
            points: chore.points
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
