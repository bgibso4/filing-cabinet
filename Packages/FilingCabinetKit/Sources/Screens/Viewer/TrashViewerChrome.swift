import Core
import ScreenModels
import SwiftUI

/// The bottom of a scan opened from Trash (Trash.dc.html lines 167-170): Delete now in glass and Restore filled, in
/// place of the viewer's bar. Restore asks nothing (M10); Delete now asks first, naming the scan (09-06). Either way
/// the scan leaves Trash, the viewer pops back to it (M6) and VoiceOver hears what happened (M19).
struct TrashViewerChrome: View {
    let model: ViewerModel
    /// After a restore. The success haptic plays from a screen that stays: this one pops in the same update.
    let onRestored: () -> Void

    var body: some View {
        TrashActionBar(
            deleteTitle: String(localized: "Delete now", bundle: #bundle),
            restoreTitle: String(localized: "Restore", bundle: #bundle),
            deleteIdentifier: AccessibilityID.TrashViewer.deleteNow,
            restoreIdentifier: AccessibilityID.TrashViewer.restore,
            onDelete: model.deleteNow,
            onRestore: restore,
            confirmation: model.confirmation,
            onCancel: model.cancelConfirmation,
            onConfirm: model.performConfirmation
        )
    }

    private func restore() {
        guard let announcement = model.restore() else { return }
        onRestored()
        AccessibilityNotification.Announcement(announcement).post()
    }
}
