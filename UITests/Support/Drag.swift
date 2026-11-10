import XCTest

extension XCUIElement {
    /// Drags from the element's centre by `distance` points (down when positive), slowly enough that it doesn't fling,
    /// and holds a moment before lifting.
    func drag(by distance: CGFloat) {
        let start = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(
            forDuration: 0.1,
            thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)),
            withVelocity: .slow,
            thenHoldForDuration: 0.3
        )
    }
}
