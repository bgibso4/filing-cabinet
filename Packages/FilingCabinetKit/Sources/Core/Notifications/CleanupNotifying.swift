/// The seam to iOS notifications: the system implementation and `FakeNotificationCenter` stand behind it.
package protocol CleanupNotifying: Sendable {
    func authorization() async -> NotificationAuthorization

    /// Asks iOS once; true when the person allowed notes.
    func requestAuthorization() async -> Bool

    // periphery:ignore - first used by Task 12 (Settings screens, notification scheduling)
    /// Makes `notices` the only pending notes.
    func replacePending(with notices: [ScheduledNotice]) async
}
