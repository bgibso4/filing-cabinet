import Core
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
    },
    // On iOS 27 the audit reports text as clipped on any floating sheet (any detent shorter than .large), even with the
    // text intact. Ben chose the mocks' compact camera-off sheet knowing this (2026-11-06). Only textClipped, and only
    // this sheet's three text elements, matched by identifier; any other screen's clipped text still fails.
    { _, issue in
        guard issue.auditType == .textClipped, let element = issue.element else { return false }
        let sheetText = [
            AccessibilityID.CameraOff.title, AccessibilityID.CameraOff.message, AccessibilityID.CameraOff.openSettings,
        ]
        return sheetText.contains(element.identifier)
    },
    // In dark mode the audit misreads the viewer header's white text on dark Liquid Glass and reports low contrast,
    // though the text is the primary colour and its element screenshot reads clearly (on file in Task 20's reports).
    // Ben accepted this on 2026-11-07. Only contrast, only while the device is in dark mode, and only the header's title
    // line (the audit reports it on its own, inside the combined header); the time-left line still fails.
    { _, issue in
        guard issue.auditType == .contrast, XCUIDevice.shared.appearance == .dark, let element = issue.element else {
            return false
        }
        return element.identifier == AccessibilityID.pillTitle(AccessibilityID.Viewer.header)
    },
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
