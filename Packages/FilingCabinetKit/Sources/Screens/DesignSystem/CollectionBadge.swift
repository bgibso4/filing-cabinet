import Core
import SwiftUI

/// The round colour badge with a collection's white symbol, as on Home rows.
struct CollectionBadge: View {
    let collection: BuiltInCollection

    // Home.dc.html: the badge is 34 pt with a 19 pt symbol at the default and the large-text variant alike,
    // so it never grows with Dynamic Type; only the row around it does.
    private static let diameter: CGFloat = 34
    private static let symbolSize: CGFloat = 19

    var body: some View {
        Circle()
            .fill(Tokens.Color.badge(collection))
            .frame(width: Self.diameter, height: Self.diameter)
            .overlay {
                Tokens.symbol(collection)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Self.symbolSize, height: Self.symbolSize)
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}
