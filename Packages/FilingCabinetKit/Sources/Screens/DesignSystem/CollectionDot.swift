import Core
import SwiftUI

/// The small dot that names a scan's collection where a screen mixes collections.
struct CollectionDot: View {
    let collection: BuiltInCollection

    // Collection.dc.html line 67: the dot is 7 pt.
    private static let diameter: CGFloat = 7

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: Self.diameter, height: Self.diameter)
            .accessibilityHidden(true)
    }

    private var color: Color {
        switch collection {
        case .wallet: Tokens.Color.collWallet
        case .receipts: Tokens.Color.collReceipts
        case .notes: Tokens.Color.collNotes
        case .documents: Tokens.Color.collDocuments
        case .throwaways: Tokens.Color.collThrowaways
        }
    }
}
