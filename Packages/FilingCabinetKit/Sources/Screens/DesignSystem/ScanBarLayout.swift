import SwiftUI

extension EnvironmentValues {
    /// True while the camera or review covers the screens. The cover is clear, so they stay in the window and in the
    /// accessibility tree unless they hide themselves.
    @Entry var captureLayerIsUp = false
}

/// A screen's scrolling content with the Scan button at the bottom centre (see `BottomBarLayout`), or, while there is
/// one, a bar that takes its place (a grid's select bar, #68, as Trash's replaces Empty Trash).
struct ScanBarLayout<Content: View, Replacement: View>: View {
    /// False keeps the button disabled (until launch cleanup has finished).
    let canScan: Bool
    let scanIdentifier: String
    let onScan: () -> Void
    let content: Content
    /// Shown instead of Scan while not nil.
    let replacement: Replacement?

    @Environment(\.captureLayerIsUp) private var captureLayerIsUp

    init(
        canScan: Bool,
        scanIdentifier: String,
        onScan: @escaping () -> Void,
        replacement: Replacement?,
        @ViewBuilder content: () -> Content
    ) {
        self.canScan = canScan
        self.scanIdentifier = scanIdentifier
        self.onScan = onScan
        self.replacement = replacement
        self.content = content()
    }

    var body: some View {
        BottomBarLayout {
            content
        } bar: {
            if let replacement { replacement } else { button }
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

extension ScanBarLayout where Replacement == EmptyView {
    /// Scan alone (Home).
    init(canScan: Bool, scanIdentifier: String, onScan: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.init(
            canScan: canScan, scanIdentifier: scanIdentifier, onScan: onScan, replacement: nil, content: content)
    }
}
