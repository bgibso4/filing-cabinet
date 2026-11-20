import Core
import UserNotifications

/// The system's notification center. Cleanup notes are alerts with the default sound: no badge, one thread.
public struct SystemNotificationCenter: CleanupNotifying {
    private static let threadIdentifier = "cleanup"
    /// What the app asks iOS to allow.
    static let options: UNAuthorizationOptions = [.alert, .sound]

    public init() {}

    public func authorization() async -> NotificationAuthorization {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return Self.authorization(for: settings.authorizationStatus)
    }

    public func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: Self.options)
        } catch {
            ScreensLog.logger.error("Asking for notifications failed: \(error.localizedDescription, privacy: .private)")
            return false
        }
    }

    public func replacePending(with notices: [ScheduledNotice]) async {
        let center = UNUserNotificationCenter.current()
        let stale = await center.pendingNotificationRequests().map(\.identifier).filter(Self.isCleanup)
        center.removePendingNotificationRequests(withIdentifiers: stale)
        var failed = 0
        for notice in notices {
            let content = Self.content(for: notice)
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

    static func content(for notice: ScheduledNotice) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = notice.title
        content.body = notice.body
        content.threadIdentifier = threadIdentifier
        content.sound = .default
        return content
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
