import Foundation

/// One note the app asks iOS to deliver on a day: it fires at `fireDate` and never repeats.
public struct ScheduledNotice: Sendable, Equatable {
    /// Every cleanup note's id starts with this, so replacing them leaves any other pending note alone.
    package static let idPrefix = "cleanup-"

    package let id: String
    package let fireDate: DateComponents
    package let title: String
    package let body: String

    package init(id: String, fireDate: DateComponents, title: String, body: String) {
        self.id = id
        self.fireDate = fireDate
        self.title = title
        self.body = body
    }
}
