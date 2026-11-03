import XCTest

/// Issues the audit may ignore. Each entry needs a comment with the reason it is a false positive.
@MainActor
private let ignoredIssues: [(XCUIApplication, XCUIAccessibilityAuditIssue) -> Bool] = [
    // At the largest text size the list is taller than the screen, and a row's label can start in the last point
    // of the window (the audit found "Notes" at y 872.7 in an 874 pt window). That text is scrolled out of view
    // and sits under the Scan button's fade, so the audit samples background pixels and reports low contrast.
    // Only contrast, only an element that begins within 2 pt of the window's bottom edge or below it.
    { app, issue in
        guard issue.auditType == .contrast, let element = issue.element else { return false }
        return element.frame.minY >= app.windows.firstMatch.frame.maxY - 2
    }
]

/// The only call site of `performAccessibilityAudit`. Audit types are listed explicitly, not left to the default.
@MainActor
func audit(_ app: XCUIApplication) throws {
    // .action and .parentChild are left out: they flag SwiftUI's own container/action semantics, not our elements.
    let types: XCUIAccessibilityAuditType = [
        .contrast, .elementDetection, .hitRegion, .sufficientElementDescription,
        .dynamicType, .textClipped, .trait,
    ]
    try app.performAccessibilityAudit(for: types) { issue in
        ignoredIssues.contains { $0(app, issue) }
    }
}
