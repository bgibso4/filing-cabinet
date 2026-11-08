import XCTest

/// Every id exists on screen, and no button has an empty identifier.
///
/// Reads one snapshot of the accessibility tree per attempt instead of one query per id: each query costs about a
/// second on CI. Same 5 s bound as a `waitForExistence` per id.
@MainActor
func assertIdentifiers(
    _ ids: [String], in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line
) {
    let deadline = Date.now.addingTimeInterval(5)
    var elements: [XCUIElementSnapshot] = []
    var missing = ids
    while true {
        // try?: the snapshot throws while the app is between states; the next attempt, or the failures below,
        // report it.
        elements = (try? app.snapshot()).map(flattened) ?? []
        let found = Set(elements.map(\.identifier))
        missing = ids.filter { !found.contains($0) }
        if missing.isEmpty || Date.now >= deadline { break }
        Thread.sleep(forTimeInterval: 0.1)
    }
    for id in missing {
        XCTFail(id, file: file, line: line)
    }
    for button in elements where button.elementType == .button {
        XCTAssertFalse(button.identifier.isEmpty, button.label, file: file, line: line)
    }
}

/// The element and everything under it.
private func flattened(_ element: XCUIElementSnapshot) -> [XCUIElementSnapshot] {
    [element] + element.children.flatMap(flattened)
}
