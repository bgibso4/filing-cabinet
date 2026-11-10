import SwiftUI
import UIKit

/// The look of the system bar's own titles (plan 3, E9): the title in New York in both sizes, the subtitle in secondary
/// text, on a clear bar so the back button is the system's glass one. Set once at launch, before the first bar exists:
/// the fonts are fixed at the text size then, and the colours follow light and dark live.
///
/// SwiftUI ignores this appearance on a screen with `.toolbarBackground(.hidden, for: .navigationBar)`, so header
/// screens don't use it: the clear appearance is what clears their bar.
@MainActor
public enum HeaderAppearance {
    public static func install() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [
            .font: font(Tokens.Typography.headline, style: .headline, serif: true),
            .foregroundColor: color(Tokens.Color.textPrimary),
        ]
        appearance.largeTitleTextAttributes = [
            .font: font(Tokens.Typography.largeTitle, style: .largeTitle),
            .foregroundColor: color(Tokens.Color.textPrimary),
            .kern: Tokens.Typography.largeTitleTracking,
        ]
        // The bar draws the large subtitle with these too: it ignores `largeSubtitleTextAttributes` (Axiom, verified on
        // iOS 26.5 and 27.0, and here).
        appearance.subtitleTextAttributes = [
            .font: font(Tokens.Typography.caption, style: .caption1),
            .foregroundColor: subtitleColor,
        ]
        let bar = UINavigationBar.appearance()
        bar.standardAppearance = appearance
        bar.scrollEdgeAppearance = appearance
        bar.compactAppearance = appearance
    }

    /// The large subtitle's font (Settings2.dc.html), for the item's attributed large subtitle (`LargeSubtitle`).
    static var largeSubtitleFont: UIFont { font(Tokens.Typography.subheadline, style: .subheadline) }

    static var subtitleColor: UIColor { color(Tokens.Color.textSecondary) }

    /// The large title's line height at `typeSize`: the height the bar's large title adds to the collapsed bar, for
    /// telling the bar's collapse from it laying out again a few points shorter (`HeaderInsets`). One line, since the
    /// bar truncates the large title rather than wrapping it.
    static func largeTitleHeight(at typeSize: DynamicTypeSize) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(typeSize))
        return UIFontMetrics(forTextStyle: .largeTitle).scaledFont(
            for: defaultSize(Tokens.Typography.largeTitle), compatibleWith: traits
        ).lineHeight
    }

    /// The token's font at the default text size, scaled as the system scales `style` for the text size the app
    /// launched at: the appearance is installed once, so a change of text size shows at the next launch. Launched at
    /// the largest size, the small title and subtitle come out scaled (1.1 and 1.3 times, measured on Collections
    /// at AX5), and the bar still fits them (`HeaderFitTests` measures at the default size).
    /// `serif` puts a token in New York that the design system keeps in SF elsewhere (the small title is headline).
    private static func font(_ token: Font, style: UIFont.TextStyle, serif: Bool = false) -> UIFont {
        UIFontMetrics(forTextStyle: style).scaledFont(for: defaultSize(token, serif: serif))
    }

    /// The token's font at the default text size.
    private static func defaultSize(_ token: Font, serif: Bool = false) -> UIFont {
        var environment = EnvironmentValues()
        environment.dynamicTypeSize = .large
        let font = token.resolve(in: environment.fontResolutionContext).ctFont as UIFont
        guard serif, let descriptor = font.fontDescriptor.withDesign(.serif) else { return font }
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }

    /// The token's colour, following light and dark as the bar's trait collection changes.
    private static func color(_ token: Color) -> UIColor {
        UIColor { traits in
            var environment = EnvironmentValues()
            environment.colorScheme = traits.userInterfaceStyle == .dark ? .dark : .light
            return UIColor(Color(token.resolve(in: environment)))
        }
    }
}
