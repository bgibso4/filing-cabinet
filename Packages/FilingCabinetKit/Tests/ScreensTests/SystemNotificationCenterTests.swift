#if canImport(UIKit)
    import Core
    import Testing
    import UserNotifications

    @testable import Screens

    @Test(arguments: [
        (UNAuthorizationStatus.authorized, NotificationAuthorization.authorized),
        // Provisional and ephemeral notes are delivered, so they count as allowed.
        (.provisional, .authorized),
        (.ephemeral, .authorized),
        (.denied, .denied),
        (.notDetermined, .notDetermined),
    ])
    func systemStatusMapsToAuthorization(_ status: UNAuthorizationStatus, _ expected: NotificationAuthorization) {
        #expect(SystemNotificationCenter.authorization(for: status) == expected)
    }

    @Test func onlyCleanupRequestsAreReplaced() {
        #expect(SystemNotificationCenter.isCleanup(ScheduledNotice.idPrefix + "2026-10-12"))
        #expect(!SystemNotificationCenter.isCleanup("reminder-1"))
    }

    @Test func theAppAsksForAlertsAndSound() {
        #expect(SystemNotificationCenter.options == [.alert, .sound])
    }

    @Test func aCleanupNotePlaysTheDefaultSound() {
        let notice = ScheduledNotice(
            id: ScheduledNotice.idPrefix + "2026-10-12",
            fireDate: DateComponents(year: 2026, month: 10, day: 12, hour: 9),
            title: "3 scans cleaned up",
            body: "They are in Trash for 30 days.")

        let content = SystemNotificationCenter.content(for: notice)

        #expect(content.sound == .default)
        #expect(content.title == notice.title)
        #expect(content.body == notice.body)
        #expect(content.threadIdentifier == "cleanup")
    }
#endif
