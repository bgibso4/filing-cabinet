import CoreGraphics

/// Where a page sits along one axis of the viewer's full-screen page: the room before and after it. A page that fits
/// the region between the controls is centred in that region, so at rest the whole page shows between them. Zoomed past
/// that, the controls' room shrinks in proportion until the page reaches the screen's edges, so a zoomed page fills the
/// screen under the glass controls and never jumps on the way.
package struct PageAxisInsets: Equatable {
    package let leading: CGFloat
    package let trailing: CGFloat

    package init(leading: CGFloat, trailing: CGFloat) {
        self.leading = leading
        self.trailing = trailing
    }

    /// `content` is the page's length at its current zoom, `bounds` the screen's, and `fitLeading` and `fitTrailing`
    /// the room the controls take at either end.
    package init(content: CGFloat, bounds: CGFloat, fitLeading: CGFloat, fitTrailing: CGFloat) {
        let region = bounds - fitLeading - fitTrailing
        if content <= region {
            let gap = (region - content) / 2
            self.init(leading: fitLeading + gap, trailing: fitTrailing + gap)
            return
        }
        let spare = max(0, bounds - content)
        let controls = fitLeading + fitTrailing
        let leading = controls > 0 ? spare * fitLeading / controls : spare / 2
        self.init(leading: leading, trailing: spare - leading)
    }
}
