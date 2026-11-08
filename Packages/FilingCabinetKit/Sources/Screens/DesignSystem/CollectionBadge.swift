import Core
import SwiftUI

/// The round colour badge with a collection's white symbol, as on Home rows and Review's collection row. It never
/// grows with Dynamic Type; only the row around it does.
struct CollectionBadge: View {
    let collection: BuiltInCollection
    // Home.dc.html: on Home the badge is 34 pt with a 19 pt symbol, at the default and the large-text variant alike.
    var diameter: CGFloat = 34
    var symbolSize: CGFloat = 19

    var body: some View {
        Circle()
            .fill(Tokens.Color.badge(collection))
            .frame(width: diameter, height: diameter)
            .overlay {
                Tokens.symbol(collection)
                    .resizable()
                    .scaledToFit()
                    .frame(width: symbolSize, height: symbolSize)
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}
