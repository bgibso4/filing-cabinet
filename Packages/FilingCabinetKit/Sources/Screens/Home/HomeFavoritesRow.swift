import Core
import Library
import ScreenModels
import SwiftUI

/// Home's Favorites (02-01, M18): "Favorites ›" as a header that links to the Favorites grid from one favourite (B15),
/// then the first favourites as cards in a row that scrolls sideways, each its thumbnail with its title under it. A
/// card opens its scan.
struct HomeFavoritesRow: View {
    let favorites: [HomeFavorite]
    let thumbnails: any ThumbnailProviding
    let onOpenGrid: () -> Void
    let onOpen: (ScanID) -> Void

    // Home.dc.html lines 80 and 85: the header is at least 44 pt tall and sits 6 pt below what is above it.
    private static let headerMinHeight: CGFloat = 44
    private static let headerTopGap: CGFloat = 6
    // Home.dc.html line 81: 7 pt between "Favorites" and its chevron.
    private static let chevronGap: CGFloat = 7
    // Home.dc.html lines 314-315 (`cardW`, `cardH`): cards are 148 × 96 pt, and 240 × 155 pt at the largest text.
    private static let cardSize = CGSize(width: 148, height: 96)
    private static let largeCardSize = CGSize(width: 240, height: 155)
    // Home.dc.html line 89: 8 pt between cards, which scroll under the screen's 16 pt margins.
    private static let cardGap = Tokens.Spacing.s2
    // Home.dc.html line 90: 6 pt between a card's picture and its title.
    private static let titleGap: CGFloat = 6

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .frame(minHeight: Self.headerMinHeight)
                .padding(.top, Self.headerTopGap)
            cards
        }
    }

    private var header: some View {
        Button(action: onOpenGrid) {
            HStack(spacing: Self.chevronGap) {
                title
                Image(systemName: "chevron.right")
                    // Headline is closest to the mock's 15 pt chevron beside a 22 pt title.
                    .font(Tokens.Typography.headline)
                    .foregroundStyle(Tokens.Color.textSecondary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // Home.dc.html line 81.
        .accessibilityLabel(Text("Favorites, see all", bundle: #bundle))
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier(AccessibilityID.Home.favoritesLink)
    }

    private var title: some View {
        Text("Favorites", bundle: #bundle)
            .font(Tokens.Typography.title2)
            .foregroundStyle(Tokens.Color.textPrimary)
    }

    private var cards: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: Self.cardGap) {
                ForEach(favorites) { favorite in
                    card(favorite)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, Tokens.Spacing.s4, for: .scrollContent)
        // Out to the screen's edges: the cards scroll under Home's margins (Home.dc.html line 89).
        .padding(.horizontal, -Tokens.Spacing.s4)
    }

    private func card(_ favorite: HomeFavorite) -> some View {
        let size = typeSize.isAccessibilitySize ? Self.largeCardSize : Self.cardSize
        return Button {
            onOpen(favorite.id)
        } label: {
            VStack(alignment: .leading, spacing: Self.titleGap) {
                ThumbnailView(id: favorite.id, page: 0, provider: thumbnails)
                    .frame(width: size.width, height: size.height)
                    .clipShape(.rect(cornerRadius: Tokens.Radius.nested))
                Text(favorite.title)
                    .font(Tokens.Typography.subheadline.weight(.semibold))
                    .foregroundStyle(Tokens.Color.textPrimary)
                    // Home.dc.html line 92: one line with an ellipsis; above the default size it wraps rather than
                    // cutting off (requirements 06 · Accessibility).
                    .lineLimit(typeSize <= .large ? 1 : nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: size.width, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(favorite.title)
        .accessibilityIdentifier(AccessibilityID.Home.favorite(favorite.id))
    }
}
