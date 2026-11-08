import Foundation

/// One note the app asks iOS to deliver on a day: it fires at `fireDate` and never repeats.
package struct ScheduledNotice: Sendable, Equatable {
    // periphery:ignore - first used by Task 12 (Settings screens, notification scheduling)
    package let id: String
    // periphery:ignore - first used by Task 12 (Settings screens, notification scheduling)
    package let fireDate: DateComponents
    // periphery:ignore - first used by Task 12 (Settings screens, notification scheduling)
    package let title: String
    // periphery:ignore - first used by Task 12 (Settings screens, notification scheduling)
    package let body: String

    // periphery:ignore - first used by Task 12 (Settings screens, notification scheduling)
    package init(id: String, fireDate: DateComponents, title: String, body: String) {
        self.id = id
        self.fireDate = fireDate
        self.title = title
        self.body = body
    }
}
