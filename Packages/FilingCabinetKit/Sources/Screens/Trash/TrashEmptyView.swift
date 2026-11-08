import Core
import SwiftUI

/// What Trash shows with nothing in it (09-09): the trash symbol, "Trash is empty" and how Trash works.
struct TrashEmptyView: View {
    // Trash.dc.html line 66: the symbol is 44 pt.
    private static let symbolSize: CGFloat = 44
    // Trash.dc.html line 68: the sentence is at most 290 pt wide. At accessibility sizes it takes the full width.
    private static let messageMaxWidth: CGFloat = 290

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: Tokens.Spacing.s2) {
            Image(systemName: "trash")
                .resizable()
                .scaledToFit()
                .fontWeight(.light)
                .frame(width: Self.symbolSize, height: Self.symbolSize)
                .foregroundStyle(Tokens.Color.textSecondary)
                .accessibilityHidden(true)
            Text("Trash is empty", bundle: #bundle)
                .font(Tokens.Typography.headline)
                .foregroundStyle(Tokens.Color.textPrimary)
            Text(
                "Scans land here when they expire or you move them here. Each one stays \(Lifecycle.trashDays) days, then it’s deleted.",
                bundle: #bundle
            )
            .font(Tokens.Typography.subheadline)
            .foregroundStyle(Tokens.Color.textSecondary)
            .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : Self.messageMaxWidth)
        }
        .multilineTextAlignment(.center)
    }
}
