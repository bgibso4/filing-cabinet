import ScreenModels
import SwiftUI

extension View {
    /// What Delete and Empty Trash ask first (09-06 … 09-08), with a warning haptic as it comes up. Attached to the
    /// button that asked, it comes up from that button, as Photos' delete does (Ben, 2026-11-08); the system draws the
    /// destructive action red. Dismissing it any way clears the confirmation; its action performs the confirmation it
    /// presented, so the order of the two doesn't matter. `perform` returns what VoiceOver announces once it is done
    /// (M19), or nil when the write failed.
    func trashConfirmationDialog(
        _ confirmation: TrashConfirmation?,
        cancel: @escaping () -> Void,
        perform: @escaping (TrashConfirmation) async -> String?
    ) -> some View {
        self
            .sensoryFeedback(.warning, trigger: confirmation) { _, confirmation in confirmation != nil }
            .confirmationDialog(
                confirmation?.title ?? "",
                isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { cancel() } }),
                titleVisibility: .visible,
                presenting: confirmation
            ) { confirmation in
                Button(role: .cancel, action: cancel) { Text("Cancel", bundle: #bundle) }
                Button(role: .destructive) {
                    Task {
                        if let announcement = await perform(confirmation) {
                            AccessibilityNotification.Announcement(announcement).post()
                        }
                    }
                } label: {
                    Text(confirmation.confirmTitle)
                }
            } message: { confirmation in
                Text(confirmation.message)
            }
    }
}
