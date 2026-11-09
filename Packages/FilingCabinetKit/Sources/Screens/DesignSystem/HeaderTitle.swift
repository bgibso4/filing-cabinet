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
    /// True under the capture layer: the small title and subtitle leave the accessibility tree, as the screen under the
    /// layer does (the bar isn't inside the screen's view, so the root's hiding doesn't reach it).
    let isHidden: Bool
    /// The screen's text size, read outside the bar: the bar hosts its title items at a clamped size, so the large title
    /// takes it back from here to grow at any size (M7).
    let typeSize: DynamicTypeSize
    /// The large title's height as drawn, so a screen resting large knows where the bar collapses before it has.
    let onLargeTitleHeight: (CGFloat) -> Void

    // Plan 3, Task 3: the large subtitle sits 2 pt under the large title (Settings2.dc.html line 51).
    private static let largeSubtitleGap: CGFloat = 2

    var body: some ToolbarContent {
        ToolbarItem(placement: .title) {
            title
                .font(Tokens.Typography.headline)
                .fontDesign(.serif)
                .foregroundStyle(Tokens.Color.textPrimary)
                .modifier(BarText(growth: growth))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(identifier)
                .modifier(HiddenUnderCapture(isHidden: isHidden))
        }
        if let subtitle {
            ToolbarItem(placement: .subtitle) {
                subtitle
                    .font(Tokens.Typography.caption)
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .modifier(BarText(growth: growth))
                    .accessibilityIdentifier(AccessibilityID.headerSubtitle(identifier))
                    .modifier(HiddenUnderCapture(isHidden: isHidden))
            }
        }
        ToolbarItem(placement: .largeTitle) {
            VStack(alignment: .leading, spacing: Self.largeSubtitleGap) {
                title
                    .font(Tokens.Typography.largeTitle)
                    .tracking(Tokens.Typography.largeTitleTracking)
                    .foregroundStyle(Tokens.Color.textPrimary)
                if let subtitle {
                    subtitle
                        .font(Tokens.Typography.subheadline)
                        .foregroundStyle(Tokens.Color.textSecondary)
                }
            }
            // Wraps rather than truncating: the bar's slot proposes one line's height.
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dynamicTypeSize(typeSize)
            .onGeometryChange(for: CGFloat.self, of: \.size.height) { onLargeTitleHeight($0) }
            .accessibilityHidden(true)
        }
    }
}

/// The small title's and subtitle's shared look in the bar: the default text size whatever the setting, as Apple's bars
/// are (M7), with the large-content viewer on a long press instead, never truncated (B13), and faded out while the
/// large title shows.
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
