import SwiftUI

/// A screen's scrolling content with a bar of buttons at the bottom centre (Scan, Empty Trash). At default sizes the bar
/// floats over the content on a fade of the screen background (as a safe-area inset it pushes the scroll content up by
/// its real size). At accessibility sizes the content is taller than the screen, so a row would rest half under the
/// fade: the content ends where the bar's area begins instead, and the bar sits on the plain background.
struct BottomBarLayout<Content: View, Bar: View>: View {
    @ViewBuilder let content: Content
    @ViewBuilder let bar: Bar

    // Home.dc.html: the fade behind the pill is solid from 38% of its height.
    private var fadeSolidLocation: Double { 0.38 }

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: 0) {
                content
                barArea(fades: false)
            }
            .background(Tokens.Color.bgGrouped)
        } else {
            content
                .background(Tokens.Color.bgGrouped)
                .safeAreaInset(edge: .bottom, spacing: 0) { barArea(fades: true) }
        }
    }

    private func barArea(fades: Bool) -> some View {
        bar
            .padding(.top, Tokens.Spacing.s4)
            .frame(maxWidth: .infinity)
            .background {
                if fades {
                    LinearGradient(
                        stops: [
                            .init(color: Tokens.Color.bgGrouped.opacity(0), location: 0),
                            .init(color: Tokens.Color.bgGrouped, location: fadeSolidLocation),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea(edges: .bottom)
                    .allowsHitTesting(false)
                }
            }
    }
}
