import SwiftUI

extension EnvironmentValues {
    /// True while the camera or review covers the screens. The cover is clear, so they stay in the window and in the
    /// accessibility tree unless they hide themselves.
    @Entry var captureLayerIsUp = false
}

/// A screen's scrolling content with the Scan button at the bottom centre (see `BottomBarLayout`).
struct ScanBarLayout<Content: View>: View {
    /// False keeps the button disabled (until launch cleanup has finished).
    let canScan: Bool
    let scanIdentifier: String
    let onScan: () -> Void
    @ViewBuilder let content: Content

    @Environment(\.captureLayerIsUp) private var captureLayerIsUp

    var body: some View {
        BottomBarLayout {
            content
        } bar: {
            button
        }
    }

    /// `accessibilityHidden` doesn't take the button out of the accessibility tree (measured in a UI test, with the
    /// cause unknown; still so with the glass pill as an overlay, 2026-11-10); `hidden()` does, and keeps its place so
    /// nothing moves when the layer goes.
    @ViewBuilder
    private var button: some View {
        let scan = ScanButton(identifier: scanIdentifier, action: onScan).disabled(!canScan)
        if captureLayerIsUp { scan.hidden() } else { scan }
    }
}
