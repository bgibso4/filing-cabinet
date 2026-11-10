import Core
import SwiftUI

/// The viewer's bottom bar (ScanView.dc.html lines 260-268): the heart and Info in a glass pill at the centre (06-01),
/// and Trash at the trailing edge, which asks first (06-04). Info opens Details. Share comes later in Plan 4.
struct ViewerBottomBar: View {
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    let onDetails: () -> Void
    /// What Trash's confirmation says.
    let trashMessage: String
    /// The confirmation's Move to Trash.
    let onTrash: () -> Void

    @State private var isConfirmingTrash = false

    // ScanView.dc.html line 263: the pill is 10 pt either side of its 52 pt buttons, 4 pt apart.
    private static let pillPadding: CGFloat = 10
    private static let pillButtonDiameter: CGFloat = 52
    private static let pillButtonGap: CGFloat = 4
    // ScanView.dc.html line 267: Trash is 56 pt.
    private static let trashDiameter: CGFloat = 56

    var body: some View {
        ZStack {
            infoPill
            trashButton.frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var infoPill: some View {
        HStack(spacing: Self.pillButtonGap) {
            pillButton(systemImage: isFavorite ? "heart.fill" : "heart", action: onToggleFavorite)
                .accessibilityLabel(
                    isFavorite
                        ? Text("Remove from Favorites", bundle: #bundle) : Text("Add to Favorites", bundle: #bundle)
                )
                .accessibilityAddTraits(isFavorite ? .isSelected : [])
                .accessibilityIdentifier(AccessibilityID.Viewer.favorite)
                // Requirements 06 · Haptics: a light tap on favouriting, as on choosing from a menu.
                .sensoryFeedback(.selection, trigger: isFavorite)
            pillButton(systemImage: "info.circle", action: onDetails)
                .accessibilityLabel(Text("Details", bundle: #bundle))
                .accessibilityIdentifier(AccessibilityID.Viewer.details)
        }
        .padding(.horizontal, Self.pillPadding)
        .padding(.vertical, (Self.trashDiameter - Self.pillButtonDiameter) / 2)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private func pillButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                // Title 2 is closest to the mock's 24 pt glyph.
                .font(Tokens.Typography.title2.weight(.regular))
                .foregroundStyle(Tokens.Color.textPrimary)
                .frame(minWidth: Self.pillButtonDiameter, minHeight: Self.pillButtonDiameter)
                .fixedSize()
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
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
