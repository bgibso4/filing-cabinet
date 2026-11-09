import SwiftUI

/// Takes a bar item out of the accessibility tree under the capture layer: the bar isn't inside the screen's view, so
/// the root's hiding doesn't reach it. `hidden()`, as for the Scan button (`ScanBarLayout`): `accessibilityHidden`
/// leaves an element in the tree.
struct HiddenUnderCapture: ViewModifier {
    let isHidden: Bool

    func body(content: Content) -> some View {
        if isHidden { content.hidden() } else { content }
    }
}
