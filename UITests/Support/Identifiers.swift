import XCTest

/// Every id exists on screen, and no button has an empty identifier.
@MainActor
func assertIdentifiers(
    _ ids: [String], in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line
) {
    for id in ids {
        XCTAssertTrue(
            app.descendants(matching: .any)[id].waitForExistence(timeout: 5), id, file: file, line: line)
    }
    for button in app.buttons.allElementsBoundByIndex {
        XCTAssertFalse(button.identifier.isEmpty, button.label, file: file, line: line)
    }
}
