import SwiftUI

/// One screen of the welcome sheet: its content scrolls when the text is large, and its pill (and any quieter choice
/// under it) stays at the bottom.
struct WelcomePage<Content: View, Secondary: View>: View {
    let primaryIdentifier: String
    let primaryTitle: Text
    let onPrimary: () -> Void
    @ViewBuilder let content: Content
    @ViewBuilder let secondary: Secondary

    @Environment(\.dynamicTypeSize) private var typeSize

    /// The mock's margin; at accessibility sizes a narrower one, so long words fit without breaking.
    private var sidePadding: CGFloat { typeSize.isAccessibilitySize ? Tokens.Spacing.s4 : Layout.sidePadding }

    var body: some View {
        ScrollView {
            content
                .frame(maxWidth: .infinity)
                .padding(.horizontal, sidePadding)
                .padding(.top, Layout.topPadding)
                .padding(.bottom, Tokens.Spacing.s6)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: Layout.buttonGap) {
                // Opaque, as the design draws it: the audit misreads Liquid Glass pills' contrast.
                CapsuleButton(identifier: primaryIdentifier, minHeight: Layout.pillHeight, action: onPrimary) {
                    primaryTitle
                }
                secondary
            }
            .padding(.horizontal, sidePadding)
            .padding(.vertical, Tokens.Spacing.s2)
            .background(Tokens.Color.bgSurface)
        }
    }
}

extension WelcomePage where Secondary == EmptyView {
    /// A page with only its pill.
    init(
        primaryIdentifier: String,
        primaryTitle: Text,
        onPrimary: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            primaryIdentifier: primaryIdentifier,
            primaryTitle: primaryTitle,
            onPrimary: onPrimary,
            content: content,
            secondary: { EmptyView() })
    }
}

/// The page's measurements: outside `WelcomePage`, because a generic type can't hold stored statics.
private enum Layout {
    // Home.dc.html lines 213 and 241: the sheet's content starts 56 pt down and sits 32 pt in from the sides.
    static let topPadding: CGFloat = 56
    static let sidePadding: CGFloat = 32
    // Home.dc.html lines 233 and 251-252: the pill is 52 pt tall at default sizes; a text button sits 8 pt under it.
    static let pillHeight: CGFloat = 52
    static let buttonGap: CGFloat = 8
}
