import XCTest

/// An accessibility audit issue the audit may ignore. The name is what the test results report each time the
/// exemption is used (`make audit-report`), so one run shows which exemptions are still needed. The reason each one
/// is a false positive lives in a comment beside it in `Audit.swift`.
struct AuditExemption {
    let name: String
    let matches: @MainActor (XCUIApplication, XCUIAccessibilityAuditIssue) -> Bool
}
