import Core
import SwiftUI

/// A screen's title and subtitle in the system bar's four title slots (plan 3, E1): small in the bar, large under it.
///
/// The bar hides its own inline title as the large one shows, but not ours, so the small title and subtitle fade
/// themselves with `growth`. The small title is the header element in both states (M6, amended by Ben): the system
/// keeps it in the tree, so it carries `identifier` and the header trait, and the large title is only drawn.
struct HeaderTitle: ToolbarContent {
    let title: Text
    let subtitle: Text?
    let identifier: String
    /// 0 with the title small in the bar, 1 with the large title fully showing (`HeaderMotion.growth`).
    let growth: CGFloat

    var body: some ToolbarContent {
        ToolbarItem(placement: .title) {
            title
                .font(Tokens.Typography.headline)
                .fontDesign(.serif)
                .foregroundStyle(Tokens.Color.textPrimary)
                .modifier(BarText(growth: growth))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(identifier)
        }
        if let subtitle {
            ToolbarItem(placement: .subtitle) {
                subtitle
                    .font(Tokens.Typography.caption)
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .modifier(BarText(growth: growth))
                    .accessibilityIdentifier(AccessibilityID.headerSubtitle(identifier))
            }
        }
        ToolbarItem(placement: .largeTitle) {
            title
                .font(Tokens.Typography.largeTitle)
                .tracking(Tokens.Typography.largeTitleTracking)
                .foregroundStyle(Tokens.Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(true)
        }
        if let subtitle {
            ToolbarItem(placement: .largeSubtitle) {
                subtitle
                    .font(Tokens.Typography.subheadline)
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHidden(true)
            }
        }
    }
}

/// The small title's and subtitle's shared look in the bar: the default text size whatever the setting, as Apple's bars
/// are (M7), with the large-content viewer on a long press instead, never truncated (B13), and faded out while the large
/// title shows.
private struct BarText: ViewModifier {
    let growth: CGFloat

    func body(content: Content) -> some View {
        content
            .dynamicTypeSize(.large)
            .fixedSize()
            .accessibilityShowsLargeContentViewer()
            .opacity(1 - growth)
    }
}
