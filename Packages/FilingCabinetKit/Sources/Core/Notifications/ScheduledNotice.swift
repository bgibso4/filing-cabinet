import Foundation

/// One note the app asks iOS to deliver on a day: it fires at `fireDate` and never repeats.
public struct ScheduledNotice: Sendable, Equatable {
    /// Every cleanup note's id starts with this, so replacing them leaves any other pending note alone.
    package static let idPrefix = "cleanup-"

    // periphery:ignore - first used by Task 13 (CleanupNotices builds notices) and Task 14 (CleanupNotifier)
    package let id: String
    // periphery:ignore - first used by Task 13 (CleanupNotices builds notices) and Task 14 (CleanupNotifier)
    package let fireDate: DateComponents
    // periphery:ignore - first used by Task 13 (CleanupNotices builds notices) and Task 14 (CleanupNotifier)
    package let title: String
    // periphery:ignore - first used by Task 13 (CleanupNotices builds notices) and Task 14 (CleanupNotifier)
    package let body: String

    // periphery:ignore - first used by Task 13 (CleanupNotices builds notices) and Task 14 (CleanupNotifier)
    package init(id: String, fireDate: DateComponents, title: String, body: String) {
        self.id = id
        self.fireDate = fireDate
        self.title = title
        self.body = body
    }
}
