import SwiftUI

/// A screen's scrolling content with the Scan button at the bottom centre. At default sizes the button floats over
/// the content on a fade of the screen background (as a safe-area inset it pushes the scroll content up by its real
/// size). At accessibility sizes the content is taller than the screen, so a row would rest half under the fade: the
/// content ends where the button's area begins instead, and the button sits on the plain background.
struct ScanBarLayout<Content: View>: View {
    /// False keeps the button disabled (until launch cleanup has finished).
    let canScan: Bool
    let scanIdentifier: String
    let onScan: () -> Void
    @ViewBuilder let content: Content

    // Home.dc.html: the fade behind the pill is solid from 38% of its height.
    private var fadeSolidLocation: Double { 0.38 }

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: 0) {
                content
                scanBar(fades: false)
            }
            .background(Tokens.Color.bgGrouped)
        } else {
            content
                .background(Tokens.Color.bgGrouped)
                .safeAreaInset(edge: .bottom, spacing: 0) { scanBar(fades: true) }
        }
    }

    private func scanBar(fades: Bool) -> some View {
        ScanButton(identifier: scanIdentifier, action: onScan)
            .disabled(!canScan)
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
