import Core
import SwiftUI

/// The Liquid Glass header pill: a label over a supporting line ("New scan" over "1 page", "Lease 2026" over its
/// collection and time left). SF Pro, as the mocks show: it is a label, not a title.
struct PagePill<Detail: View>: View {
    private let title: Text
    private let detail: Detail
    private let identifier: String
    private let shape: AnyShape

    // Review.dc.html line 218: 5 pt above, 6 pt below and 20 pt either side of the text.
    private static var topPadding: CGFloat { 5 }
    private static var bottomPadding: CGFloat { 6 }
    private static var sidePadding: CGFloat { 20 }

    @Environment(\.colorScheme) private var colorScheme

    init(
        title: Text,
        identifier: String,
        shape: AnyShape = AnyShape(.capsule),
        @ViewBuilder detail: () -> Detail
    ) {
        self.shape = shape
        self.title = title
        self.identifier = identifier
        self.detail = detail()
    }

    var body: some View {
        VStack(spacing: 0) {
            title
                .accessibilityIdentifier(AccessibilityID.pillTitle(identifier))
                .font(Tokens.Typography.headline)
                .foregroundStyle(Tokens.Color.textPrimary)
            detail
                .font(Tokens.Typography.footnote)
                // On dark glass the secondary colour falls under AA (Ben, 2026-11-07): the line takes the primary
                // colour in dark mode, and the title still leads by weight and size.
                .foregroundStyle(colorScheme == .dark ? Tokens.Color.textPrimary : Tokens.Color.textSecondary)
        }
        .multilineTextAlignment(.center)
        // Wraps rather than truncates at large sizes.
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, Self.topPadding)
        .padding(.bottom, Self.bottomPadding)
        .padding(.horizontal, Self.sidePadding)
        .glassEffect(.regular, in: shape)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}
