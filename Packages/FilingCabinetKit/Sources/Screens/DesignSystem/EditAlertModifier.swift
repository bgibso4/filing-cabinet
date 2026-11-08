import ScreenModels
import SwiftUI

extension View {
    /// The alert an edit that fails to save shows (M18): the edit changed nothing, so OK is all it offers.
    func editAlert(_ alert: EditAlert?, dismiss: @escaping () -> Void) -> some View {
        self.alert(
            alert?.title ?? "",
            isPresented: Binding(
                get: { alert != nil },
                set: { isPresented in
                    if !isPresented { dismiss() }
                }),
            presenting: alert
        ) { _ in
            Button(role: .cancel, action: dismiss) { Text("OK", bundle: #bundle) }
        } message: { alert in
            Text(alert.message)
        }
    }
}
