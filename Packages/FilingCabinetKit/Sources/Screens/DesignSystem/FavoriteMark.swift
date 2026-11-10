import SwiftUI

/// The heart on a favourite tile's thumbnail (Collection.dc.html line 64): a white heart on a dark round badge, 5 pt in
/// from the top-right corner; empty on a tile Favorites keeps after un-favouriting (M9). A mark, not a button (M13):
/// the tile's label says "favorite" or "not a favorite", so VoiceOver skips it.
struct FavoriteMark: View {
    let isFilled: Bool

    // Collection.dc.html line 64: a 26 pt circle at 55%, 5 pt in from the top-right corner.
    private static let diameter: CGFloat = 26
    private static let inset: CGFloat = 5
    private static let groundOpacity = 0.55
    // Collection.dc.html line 64: the heart is drawn 15 pt wide.
    private static let heartSize: CGFloat = 15

    var body: some View {
        Circle()
            .fill(Tokens.Color.markGround.opacity(Self.groundOpacity))
            .frame(width: Self.diameter, height: Self.diameter)
            .overlay {
                Image(systemName: isFilled ? "heart.fill" : "heart")
                    .resizable()
                    .scaledToFit()
                    .frame(width: Self.heartSize, height: Self.heartSize)
                    .foregroundStyle(.white)
            }
            .padding(Self.inset)
            .accessibilityHidden(true)
    }
}

extension View {
    /// A favourite tile's thumbnail with the heart in its top trailing corner, or an empty heart on a tile Favorites
    /// keeps (M9). Apply it after clipping the thumbnail.
    func favoriteMark(_ isFavorite: Bool, isUnfavorited: Bool = false) -> some View {
        overlay(alignment: .topTrailing) {
            if isFavorite || isUnfavorited { FavoriteMark(isFilled: isFavorite) }
        }
    }
}
