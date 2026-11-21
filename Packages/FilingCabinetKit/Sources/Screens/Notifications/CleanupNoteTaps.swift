import Core
import UserNotifications

/// Hears a tapped note from iOS and asks the root for Trash, where a cleanup note's scans are (#123). The app holds
/// it: the notification center keeps only a weak reference. A note that comes due with the app open still shows
/// nothing (#110), since this never asks iOS to present one.
nonisolated public final class CleanupNoteTaps: NSObject, UNUserNotificationCenterDelegate, Sendable {
    private let requests: ExternalRequests

    public init(requests: ExternalRequests) {
        self.requests = requests
    }

    /// Call before launch finishes, so a tap that opens the app cold is heard.
    public func listen() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// Answers iOS at once, on the thread it called on (the main thread): UIKit's own work after the answer asserts
    /// it is there. The `async` form of this method answered from a background thread, which crashed build 21 on
    /// every tapped note.
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
            let request = Self.request(forNoteWithID: response.notification.request.identifier)
        else { return }
        Task { @MainActor [requests] in requests.send(request) }
    }

    /// What tapping the note with this id asks for: Trash for a cleanup note, nothing for any other.
    static func request(forNoteWithID id: String) -> ExternalRequest? {
        SystemNotificationCenter.isCleanup(id) ? .trash : nil
    }
}
