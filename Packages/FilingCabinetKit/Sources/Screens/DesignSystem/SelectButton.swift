import SwiftUI

/// Select, or Cancel while selecting, in the bar's trailing corner: the system draws it as a glass pill beside the back
/// button. Trash's and the grids' (#68).
struct SelectButton: View {
    let isSelecting: Bool
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            isSelecting ? Text("Cancel", bundle: #bundle) : Text("Select", bundle: #bundle)
        }
        .font(Tokens.Typography.headline)
        .accessibilityIdentifier(identifier)
    }
}
