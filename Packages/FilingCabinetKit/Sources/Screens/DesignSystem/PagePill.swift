import SwiftUI

/// The Liquid Glass header pill: a label over a supporting line ("New scan" over "1 page" or "Page 2 of 3").
/// SF Pro, as the mocks show: it is a label, not a title.
struct PagePill: View {
    let title: Text
    let detail: String
    let identifier: String

    // Review.dc.html line 218: 5 pt above, 6 pt below and 20 pt either side of the text.
    private static let topPadding: CGFloat = 5
    private static let bottomPadding: CGFloat = 6
    private static let sidePadding: CGFloat = 20

    var body: some View {
        VStack(spacing: 0) {
            title
                .font(Tokens.Typography.headline)
                .foregroundStyle(Tokens.Color.textPrimary)
            Text(detail)
                .font(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Color.textSecondary)
        }
        .multilineTextAlignment(.center)
        // Wraps rather than truncates at large sizes.
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, Self.topPadding)
        .padding(.bottom, Self.bottomPadding)
        .padding(.horizontal, Self.sidePadding)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}
