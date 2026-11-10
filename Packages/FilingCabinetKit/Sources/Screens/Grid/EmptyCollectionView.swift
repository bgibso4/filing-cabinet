import ScreenModels
import SwiftUI

/// What a grid shows with nothing in it: a large badge, a title and a sentence about what goes here.
struct EmptyCollectionView: View {
    let kind: GridKind
    let title: String
    let message: String

    // Collection.dc.html line 36: the badge is 77 pt with a 43 pt symbol.
    private static let badgeDiameter: CGFloat = 77
    private static let symbolSize: CGFloat = 43
    // Collection.dc.html line 38: the sentence is at most 280 pt wide. At accessibility sizes it takes the full width.
    private static let messageMaxWidth: CGFloat = 280

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: Tokens.Spacing.s2) {
            badge
            Text(title)
                .font(Tokens.Typography.headline)
                .foregroundStyle(Tokens.Color.textPrimary)
            Text(message)
                .font(Tokens.Typography.subheadline)
                .foregroundStyle(Tokens.Color.textSecondary)
                .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : Self.messageMaxWidth)
        }
        .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private var badge: some View {
        switch kind {
        case .collection(let collection):
            CollectionBadge(collection: collection, diameter: Self.badgeDiameter, symbolSize: Self.symbolSize)
        case .recent:
            ViewBadge(symbol: ViewSymbol.recent, diameter: Self.badgeDiameter, symbolSize: Self.symbolSize)
        case .all:
            ViewBadge(symbol: ViewSymbol.all, diameter: Self.badgeDiameter, symbolSize: Self.symbolSize)
        case .favorites:
            ViewBadge(symbol: ViewSymbol.favorites, diameter: Self.badgeDiameter, symbolSize: Self.symbolSize)
        }
    }
}
