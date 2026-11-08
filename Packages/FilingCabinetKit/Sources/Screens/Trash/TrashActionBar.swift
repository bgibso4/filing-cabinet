import SwiftUI

/// Delete in glass and Restore filled, side by side: Trash's select bar (09-02) and the Trash viewer's (09-04). While
/// they can't act both labels turn secondary. At accessibility sizes they stack, so each label keeps the full width and
/// never breaks mid-word.
struct TrashActionBar: View {
    let deleteTitle: String
    let restoreTitle: String
    let deleteIdentifier: String
    let restoreIdentifier: String
    var canAct = true
    let onDelete: () -> Void
    let onRestore: () -> Void

    // Trash.dc.html lines 120-122 and 167-169: the buttons are 54 pt tall and 10 pt apart.
    private static let buttonHeight: CGFloat = 54
    private static let buttonGap: CGFloat = 10

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout =
            typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: Self.buttonGap))
            : AnyLayout(HStackLayout(spacing: Self.buttonGap))
        layout {
            Button(action: onDelete) {
                Text(deleteTitle)
                    .font(Tokens.Typography.headline)
                    .foregroundStyle(canAct ? Tokens.Color.destructive : Tokens.Color.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: Self.buttonHeight)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .contentShape(.capsule)
                    .accessibilityElement(children: .combine)
            }
            .accessibilityIdentifier(deleteIdentifier)
            Button(action: onRestore) {
                Text(restoreTitle)
                    .font(Tokens.Typography.headline)
                    .foregroundStyle(canAct ? Tokens.Color.bgGrouped : Tokens.Color.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: Self.buttonHeight)
                    .background(canAct ? Tokens.Color.textPrimary : Tokens.Color.bgWell, in: .capsule)
                    .contentShape(.capsule)
                    .accessibilityElement(children: .combine)
            }
            .accessibilityIdentifier(restoreIdentifier)
        }
        // Not .plain, which fades a disabled button below AA contrast; the labels' own colours say they are off.
        .buttonStyle(UnfadedButtonStyle())
        .disabled(!canAct)
    }
}
