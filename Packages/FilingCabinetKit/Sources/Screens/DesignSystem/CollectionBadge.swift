import Core
import SwiftUI

/// The round colour badge with a collection's white symbol, as on Home rows.
struct CollectionBadge: View {
    let collection: BuiltInCollection

    @ScaledMetric(relativeTo: .body) private var diameter = 34
    @ScaledMetric(relativeTo: .body) private var symbolSize = 19

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
