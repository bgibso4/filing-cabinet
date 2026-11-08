import Core
import UserNotifications

/// The system's notification center. Cleanup notes are alerts only: no badge, no sound, one thread.
public struct SystemNotificationCenter: CleanupNotifying {
    private static let threadIdentifier = "cleanup"

    public init() {}

    public func authorization() async -> NotificationAuthorization {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return Self.authorization(for: settings.authorizationStatus)
    }

    public func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])
        } catch {
            ScreensLog.logger.error("Asking for notifications failed: \(error.localizedDescription, privacy: .private)")
            return false
        }
    }

    // periphery:ignore - first called by Task 14 (CleanupNotifier)
    public func replacePending(with notices: [ScheduledNotice]) async {
        let center = UNUserNotificationCenter.current()
        let stale = await center.pendingNotificationRequests().map(\.identifier).filter(Self.isCleanup)
        center.removePendingNotificationRequests(withIdentifiers: stale)
        var failed = 0
        for notice in notices {
            let content = UNMutableNotificationContent()
            content.title = notice.title
            content.body = notice.body
            content.threadIdentifier = Self.threadIdentifier
            let trigger = UNCalendarNotificationTrigger(dateMatching: notice.fireDate, repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: notice.id, content: content, trigger: trigger))
            } catch {
                failed += 1
            }
        }
        // Counts only: a note's text never goes into the log.
        if failed > 0 {
            ScreensLog.logger.error(
                "Scheduling \(failed, privacy: .public) of \(notices.count, privacy: .public) cleanup notes failed")
        }
    }

    /// Provisional and ephemeral notes are delivered, so they count as allowed.
    static func authorization(for status: UNAuthorizationStatus) -> NotificationAuthorization {
        switch status {
        case .authorized, .provisional, .ephemeral: .authorized
        case .denied: .denied
        case .notDetermined: .notDetermined
        @unknown default: .denied
        }
    }

    static func isCleanup(_ identifier: String) -> Bool { identifier.hasPrefix(ScheduledNotice.idPrefix) }
}
