import SwiftUI

extension View {
    /// Move to Trash's confirmation (06-04, M19), from the viewer's Trash button and a grid's Move to Trash (#68): a
    /// warning haptic as it comes up, then, anchored to the button, a popover with no Cancel, like Photos, holding the
    /// message and one Move to Trash.
    func moveToTrashConfirmation(
        isPresented: Binding<Bool>, message: String, move: @escaping () -> Void
    ) -> some View {
        self
            .sensoryFeedback(.warning, trigger: isPresented.wrappedValue) { _, isConfirming in isConfirming }
            .confirmationDialog(
                Text("Move to Trash", bundle: #bundle), isPresented: isPresented, titleVisibility: .hidden
            ) {
                Button(action: move) { Text("Move to Trash", bundle: #bundle) }
            } message: {
                Text(message)
            }
    }
}
