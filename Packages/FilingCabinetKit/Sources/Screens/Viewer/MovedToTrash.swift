import SwiftUI

/// What VoiceOver hears once a scan goes to Trash and the viewer pops (M19).
enum MovedToTrash {
    static func announce() {
        AccessibilityNotification.Announcement(String(localized: "Moved to Trash", bundle: #bundle)).post()
    }
}
