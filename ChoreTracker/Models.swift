import Foundation

enum MemberRole: String, Codable, CaseIterable {
    case parent
    case child
}

struct FamilyMember: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var role: MemberRole
    var isManagedProfile: Bool
    var archivedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        role: MemberRole,
        isManagedProfile: Bool = false,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.isManagedProfile = isManagedProfile
        self.archivedAt = archivedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case role
        case isManagedProfile
        case archivedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        role = try container.decode(MemberRole.self, forKey: .role)
        isManagedProfile = try container.decodeIfPresent(Bool.self, forKey: .isManagedProfile) ?? false
        archivedAt = try container.decodeIfPresent(Date.self, forKey: .archivedAt)
    }
}

enum ChoreKind: String, Codable, CaseIterable {
    case assigned
    case claimable
}

enum ChoreStatus: String, Codable, CaseIterable {
    case open
    case claimed
    case awaitingApproval
    case completed
}

enum Recurrence: String, Codable, CaseIterable, Identifiable {
    case once
    case daily
    case weekdays
    case weekly
    case monthly
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .once: "One time"
        case .daily: "Daily"
        case .weekdays: "Weekdays"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .custom: "Custom"
        }
    }
}

struct Chore: Identifiable, Codable, Hashable {
    let id: UUID
    var emoji: String
    var title: String
    var detail: String
    var kind: ChoreKind
    var recurrence: Recurrence
    var dueDate: Date?
    var availableFrom: Date?
    var assignedTo: UUID?
    var claimedBy: UUID?
    var status: ChoreStatus
    var requiresApproval: Bool
    var rewardCents: Int
    var completedAt: Date?
    var paidAt: Date?
    var customWeekdays: [Int]?
    var weekInterval: Int?

    init(
        id: UUID = UUID(),
        emoji: String = "✨",
        title: String,
        detail: String = "",
        kind: ChoreKind,
        recurrence: Recurrence = .once,
        dueDate: Date? = nil,
        availableFrom: Date? = nil,
        assignedTo: UUID? = nil,
        claimedBy: UUID? = nil,
        status: ChoreStatus = .open,
        requiresApproval: Bool = true,
        rewardCents: Int = 0,
        completedAt: Date? = nil,
        paidAt: Date? = nil,
        customWeekdays: [Int]? = nil,
        weekInterval: Int? = nil
    ) {
        self.id = id
        self.emoji = emoji
        self.title = title
        self.detail = detail
        self.kind = kind
        self.recurrence = recurrence
        self.dueDate = dueDate
        self.availableFrom = availableFrom
        self.assignedTo = assignedTo
        self.claimedBy = claimedBy
        self.status = status
        self.requiresApproval = requiresApproval
        self.rewardCents = rewardCents
        self.completedAt = completedAt
        self.paidAt = paidAt
        self.customWeekdays = customWeekdays
        self.weekInterval = weekInterval
    }

    var rewardAmount: Double {
        Double(rewardCents) / 100
    }
}
