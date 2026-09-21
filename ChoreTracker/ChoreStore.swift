import Foundation

@MainActor
final class ChoreStore: ObservableObject {
    @Published var members: [FamilyMember]
    @Published var chores: [Chore]
    @Published var activeMemberID: UUID

    init() {
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
    }

    var activeMember: FamilyMember {
        members.first(where: { $0.id == activeMemberID }) ?? members[0]
    }

    var children: [FamilyMember] {
        members.filter { $0.role == .child }
    }

    var myOpenChores: [Chore] {
        chores.filter {
            $0.assignedTo == activeMemberID &&
            $0.status != .completed
        }
    }

    var claimableChores: [Chore] {
        chores.filter { $0.kind == .claimable && $0.status == .open }
    }

    var approvalQueue: [Chore] {
        chores.filter { $0.status == .awaitingApproval }
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
        chores[index].status = chores[index].requiresApproval ? .awaitingApproval : .completed
    }

    func approve(_ chore: Chore) {
        guard let index = chores.firstIndex(where: { $0.id == chore.id }) else { return }
        chores[index].status = .completed
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
        assignee: UUID?,
        requiresApproval: Bool,
        points: Int
    ) {
        let chore = Chore(
            title: title,
            detail: detail,
            kind: kind,
            recurrence: recurrence,
            assignedTo: kind == .assigned ? assignee : nil,
            requiresApproval: requiresApproval,
            points: points
        )
        chores.insert(chore, at: 0)
    }
}
