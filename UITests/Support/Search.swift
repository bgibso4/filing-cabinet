import Core
import XCTest

/// Opens Search from Home's field and returns the field, focused with its keyboard up. Search focuses the field on
/// arrival, but the keyboard can take seconds to show on a CI simulator (`systemUITimeout`), and text typed before it
/// is lost: the field stayed empty and the results never came (#144).
@MainActor
func openSearch(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
    let homeField = app.buttons[AccessibilityID.Home.search]
    XCTAssertTrue(homeField.appears(within: 5), file: file, line: line)
    homeField.tap()
    let field = app.textFields[AccessibilityID.Search.field]
    XCTAssertTrue(field.appears(within: 5), file: file, line: line)
    let keyboard = app.keyboards.firstMatch
    XCTAssertTrue(keyboard.appears(within: systemUITimeout), "the field is focused on arrival", file: file, line: line)
    return field
}
