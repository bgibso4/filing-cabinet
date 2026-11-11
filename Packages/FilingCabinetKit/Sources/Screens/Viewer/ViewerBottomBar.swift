import Core
import Library
import SwiftUI

/// The viewer's bottom bar (ScanView.dc.html lines 260-268): Share at the leading edge (06-01), the heart and Info in a
/// glass pill at the centre, and Trash at the trailing edge, which asks first (06-04). Info opens Details.
struct ViewerBottomBar: View {
    /// What Share sends: the scan as a PDF (M10); nil once the scan has gone.
    let sharedPDF: ScanPDF?
    /// The share sheet's preview title.
    let title: String
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
    private static let pillButtonGap = Tokens.Spacing.s1
    // ScanView.dc.html line 267: Trash is a circle the size of Share's (`ShareCircle`).
    private static let circleDiameter = ShareCircle<ScanPDF>.diameter
    private static let circleFont = ShareCircle<ScanPDF>.font

    var body: some View {
        ZStack {
            infoPill
            HStack {
                shareButton
                Spacer(minLength: 0)
                trashButton
            }
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        if let sharedPDF {
            ShareCircle(
                items: [sharedPDF], preview: { _ in SharePreview(title) }, identifier: AccessibilityID.Viewer.share)
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
        .padding(.vertical, (Self.circleDiameter - Self.pillButtonDiameter) / 2)
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
            font: Self.circleFont,
            label: Text("Move to Trash", bundle: #bundle),
            identifier: AccessibilityID.Viewer.trash,
            diameter: Self.circleDiameter,
            action: { isConfirmingTrash = true }
        )
        .moveToTrashConfirmation(isPresented: $isConfirmingTrash, message: trashMessage, move: onTrash)
    }
}
