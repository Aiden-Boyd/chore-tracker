import Foundation
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()

    enum Keys {
        static let notificationsEnabled = "notifications.enabled"
        static let dueReminders = "notifications.due-reminders"
        static let overdueReminders = "notifications.overdue-reminders"
        static let approvalReminders = "notifications.approval-reminders"
        static let reminderLeadMinutes = "notifications.lead-minutes"
    }

    init() {
        registerDefaults()
    }

    var notificationsEnabled: Bool {
        UserDefaults.standard.bool(forKey: Keys.notificationsEnabled)
    }

    var dueRemindersEnabled: Bool {
        UserDefaults.standard.bool(forKey: Keys.dueReminders)
    }

    var overdueRemindersEnabled: Bool {
        UserDefaults.standard.bool(forKey: Keys.overdueReminders)
    }

    var approvalRemindersEnabled: Bool {
        UserDefaults.standard.bool(forKey: Keys.approvalReminders)
    }

    var reminderLeadMinutes: Int {
        let value = UserDefaults.standard.integer(forKey: Keys.reminderLeadMinutes)
        return value == 0 ? 60 : value
    }

    func requestPermission() async {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            // The settings screen reflects the actual system authorization state.
        }
        await refreshAuthorizationStatus()
    }

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func reschedule(for store: ChoreStore) async {
        await refreshAuthorizationStatus()

        center.removeAllPendingNotificationRequests()

        guard notificationsEnabled,
              authorizationStatus == .authorized || authorizationStatus == .provisional else {
            return
        }

        if store.activeMember.role == .child {
            if dueRemindersEnabled {
                await scheduleDueReminders(for: store.myOpenChores)
            }

            if overdueRemindersEnabled {
                await scheduleOverdueReminder(for: store.myOpenChores)
            }
        } else if approvalRemindersEnabled {
            await scheduleApprovalReminder(count: store.approvalQueue.count)
        }
    }

    private func scheduleDueReminders(for chores: [Chore]) async {
        let now = Date()

        for chore in chores {
            guard let dueDate = chore.dueDate, dueDate > now else { continue }

            let preferredReminder = dueDate.addingTimeInterval(TimeInterval(-reminderLeadMinutes * 60))
            let fireDate = preferredReminder > now ? preferredReminder : dueDate
            guard fireDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "\(chore.emoji) \(chore.title)"
            content.body = reminderLeadMinutes >= 60
                ? "This chore is due soon."
                : "This chore is coming up."
            content.sound = .default
            content.threadIdentifier = "chore-due"

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "due-\(chore.id.uuidString)",
                content: content,
                trigger: trigger
            )

            try? await center.add(request)
        }
    }

    private func scheduleOverdueReminder(for chores: [Chore]) async {
        let overdue = chores.filter { chore in
            guard let dueDate = chore.dueDate else { return false }
            return dueDate < .now && !Calendar.current.isDateInToday(dueDate)
        }

        guard !overdue.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = overdue.count == 1 ? "1 overdue chore" : "\(overdue.count) overdue chores"
        content.body = "Open Chore Tracker to see what still needs to be done."
        content.sound = .default
        content.threadIdentifier = "chore-overdue"

        var components = DateComponents()
        components.hour = 9
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "overdue-daily",
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    private func scheduleApprovalReminder(count: Int) async {
        guard count > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = count == 1 ? "1 chore needs approval" : "\(count) chores need approval"
        content.body = "Review completed chores when you have a moment."
        content.sound = .default
        content.threadIdentifier = "chore-approval"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        let request = UNNotificationRequest(
            identifier: "approval-pending",
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    private func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Keys.notificationsEnabled: true,
            Keys.dueReminders: true,
            Keys.overdueReminders: true,
            Keys.approvalReminders: true,
            Keys.reminderLeadMinutes: 60
        ])
    }
}
