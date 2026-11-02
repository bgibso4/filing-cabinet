import XCTest

/// Issues the audit may ignore. Empty to start: each entry needs a comment with the reason it is a false positive.
@MainActor
private let ignoredIssues: [(XCUIAccessibilityAuditIssue) -> Bool] = []

/// The only call site of `performAccessibilityAudit`. Audit types are listed explicitly, not left to the default.
@MainActor
func audit(_ app: XCUIApplication) throws {
    // .action and .parentChild are left out: they flag SwiftUI's own container/action semantics, not our elements.
    let types: XCUIAccessibilityAuditType = [
        .contrast, .elementDetection, .hitRegion, .sufficientElementDescription,
        .dynamicType, .textClipped, .trait,
    ]
    try app.performAccessibilityAudit(for: types) { issue in
        ignoredIssues.contains { $0(issue) }
    }
}
