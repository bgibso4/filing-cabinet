import Core
import ScreenModels
import SwiftUI

/// The bottom of a scan opened from Trash (Trash.dc.html lines 167-170): Delete now in glass and Restore filled, in
/// place of the viewer's bar. Restore asks nothing (M10); Delete now asks first, naming the scan (09-06). Either way
/// the scan leaves Trash, the viewer pops back to it (M6) and VoiceOver hears what happened (M19).
struct TrashViewerChrome: View {
    let model: ViewerModel

    /// Counts restores, so each one plays the success haptic.
    @State private var restores = 0

    var body: some View {
        TrashActionBar(
            deleteTitle: String(localized: "Delete now", bundle: #bundle),
            restoreTitle: String(localized: "Restore", bundle: #bundle),
            deleteIdentifier: AccessibilityID.TrashViewer.deleteNow,
            restoreIdentifier: AccessibilityID.TrashViewer.restore,
            onDelete: model.deleteNow,
            onRestore: restore
        )
        .sensoryFeedback(.success, trigger: restores)
        .trashConfirmationAlert(model.confirmation, cancel: model.cancelConfirmation, perform: performConfirmation)
    }

    private func restore() {
        guard let announcement = model.restore() else { return }
        restores += 1
        AccessibilityNotification.Announcement(announcement).post()
    }

    private func performConfirmation() {
        Task {
            if let announcement = await model.performConfirmation() {
                AccessibilityNotification.Announcement(announcement).post()
            }
        }
    }
}
