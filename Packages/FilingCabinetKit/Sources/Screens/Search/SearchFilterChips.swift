import Core
import ScreenModels
import SwiftUI

/// Search's filters (08-01): All, then each collection with its dot, as pills in a row that scrolls sideways under the
/// screen's margins. The chosen one is ink-filled; each is a button with the selected trait.
struct SearchFilterChips: View {
    @Binding var selection: BuiltInCollection?

    // Search.dc.html line 47: 36 pt pills, 14 pt in from each side, 8 pt apart, 6 pt from the dot to the name.
    private static let chipHeight: CGFloat = 36
    private static let chipPadding: CGFloat = 14
    private static let chipGap = Tokens.Spacing.s2
    private static let dotGap: CGFloat = 6
    // Search.dc.html line 46: the row has 4 pt above and below the pills, which the buttons take as tap area so each
    // is 44 pt tall.
    private static let rowPadding = Tokens.Spacing.s1

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Self.chipGap) {
                chip(nil)
                ForEach(BuiltInCollection.allCases, id: \.self) { chip($0) }
            }
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, Tokens.Spacing.s4, for: .scrollContent)
    }

    private func chip(_ collection: BuiltInCollection?) -> some View {
        let isSelected = selection == collection
        return Button {
            selection = collection
        } label: {
            HStack(spacing: Self.dotGap) {
                if let collection { CollectionDot(collection: collection) }
                Text(name(collection))
                    .font(Tokens.Typography.subheadline.weight(isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? Tokens.Color.bgGrouped : Tokens.Color.textPrimary)
            .padding(.horizontal, Self.chipPadding)
            .frame(minHeight: Self.chipHeight)
            .background(isSelected ? Tokens.Color.textPrimary : Tokens.Color.bgSurface, in: .capsule)
            .padding(.vertical, Self.rowPadding)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(AccessibilityID.Search.chip(collection))
    }

    private func name(_ collection: BuiltInCollection?) -> String {
        collection.map(CollectionText.name) ?? String(localized: "All", bundle: #bundle)
    }
}
