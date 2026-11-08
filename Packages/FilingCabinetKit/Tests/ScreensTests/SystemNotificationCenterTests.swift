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
#endif
