import Core
import XCTest

extension XCUIApplication {
    /// Drags the Details sheet's grabber down until the sheet closes.
    @MainActor
    func swipeDownOnSheet() {
        let sheet = descendants(matching: .any)[AccessibilityID.Details.sheet]
        let top = sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02))
        top.press(
            forDuration: 0.05, thenDragTo: windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1))
        )
    }
}
