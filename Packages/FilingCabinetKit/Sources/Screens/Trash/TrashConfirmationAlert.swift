import ScreenModels
import SwiftUI

extension View {
    /// What Delete and Empty Trash ask first (09-06 … 09-08), with a warning haptic as it comes up. Its buttons say what
    /// happens; dismissing it is only ever one of them, so the binding never clears it.
    func trashConfirmationAlert(
        _ confirmation: TrashConfirmation?, cancel: @escaping () -> Void, perform: @escaping () -> Void
    ) -> some View {
        self
            .sensoryFeedback(.warning, trigger: confirmation) { _, confirmation in confirmation != nil }
            .alert(
                confirmation?.title ?? "",
                isPresented: Binding(get: { confirmation != nil }, set: { _ in }),
                presenting: confirmation
            ) { confirmation in
                Button(role: .cancel, action: cancel) { Text("Cancel", bundle: #bundle) }
                Button(role: .destructive, action: perform) { Text(confirmation.confirmTitle) }
            } message: { confirmation in
                Text(confirmation.message)
            }
    }
}
