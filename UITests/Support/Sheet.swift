import Core
import XCTest

extension XCUIApplication {
    /// Drags the Details panel down by its grabber, to the screen's bottom edge, so it closes. The grabber sits 8 to
    /// 13 pt below the panel's top (ScanDetails.dc.html line 34), above the body, which scrolls first at large text.
    @MainActor
    func swipeDownOnSheet() {
        let sheet = descendants(matching: .any)[AccessibilityID.Details.sheet]
        let top = sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: 0, dy: 10))
        top.press(
            forDuration: 0.05, thenDragTo: windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1))
        )
    }
}
