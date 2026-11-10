import Core
import SwiftUI

/// The viewer's bottom bar (ScanView.dc.html lines 260-268): Info in a glass pill at the centre, which opens Details,
/// and Trash at the trailing edge, which asks first (06-04). Share and Favorite come with Plan 4.
struct ViewerBottomBar: View {
    let onDetails: () -> Void
    /// What Trash's confirmation says.
    let trashMessage: String
    /// The confirmation's Move to Trash.
    let onTrash: () -> Void

    @State private var isConfirmingTrash = false

    // ScanView.dc.html line 263: the pill is 10 pt either side of its 52 pt buttons.
    private static let pillPadding: CGFloat = 10
    private static let infoDiameter: CGFloat = 52
    // ScanView.dc.html line 267: Trash is 56 pt.
    private static let trashDiameter: CGFloat = 56

    var body: some View {
        ZStack {
            infoPill
            trashButton.frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var infoPill: some View {
        Button(action: onDetails) {
            Image(systemName: "info.circle")
                // Title 2 is closest to the mock's 24 pt glyph.
                .font(Tokens.Typography.title2.weight(.regular))
                .foregroundStyle(Tokens.Color.textPrimary)
                .frame(minWidth: Self.infoDiameter, minHeight: Self.infoDiameter)
                .fixedSize()
                .padding(.horizontal, Self.pillPadding)
                .padding(.vertical, (Self.trashDiameter - Self.infoDiameter) / 2)
                .glassEffect(.regular.interactive(), in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Details", bundle: #bundle))
        .accessibilityIdentifier(AccessibilityID.Viewer.details)
    }

    private var trashButton: some View {
        GlassCircleButton(
            systemImage: "trash",
            // Title 2 is closest to the mock's 23 pt glyph.
            font: Tokens.Typography.title2.weight(.regular),
            label: Text("Move to Trash", bundle: #bundle),
            identifier: AccessibilityID.Viewer.trash,
            diameter: Self.trashDiameter,
            action: { isConfirmingTrash = true }
        )
        .moveToTrashConfirmation(isPresented: $isConfirmingTrash, message: trashMessage, move: onTrash)
    }
}
