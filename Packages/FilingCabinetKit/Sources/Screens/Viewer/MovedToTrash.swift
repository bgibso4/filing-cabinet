import ScreenModels
import SwiftUI

/// What VoiceOver hears once a scan goes to Trash and the viewer pops (M19).
enum MovedToTrash {
    static func announce() {
        AccessibilityNotification.Announcement(MoveToTrashText.announcement(count: 1)).post()
    }
}
