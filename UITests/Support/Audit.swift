import Core
import XCTest

/// BottomBarLayout's padding above the Scan button (Tokens.Spacing.s4): where the content ends at accessibility sizes.
private let barTopPadding: CGFloat = 16

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
    // The same scrolled-out text at accessibility sizes, where the content ends at the top of the Scan bar's area
    // instead of under a fade (BottomBarLayout). A row label cut by that edge keeps its whole frame, so the audit
    // samples the bar area under it (the grey glyph of a disabled Scan) and reports low contrast, though the visible
    // part is full contrast (Home's "Notes" with 60 scans, Plan 3 Task 6 evidence). Approved by Ben 2026-11-09, Plan 3
    // Task 6 (#59). Only contrast, only at an accessibility text size, and only an element whose frame crosses the bar
    // area's top edge: the Scan button's top less the bar's 16 pt top padding (Tokens.Spacing.s4 in BottomBarLayout).
    { app, issue in
        guard issue.auditType == .contrast, let element = issue.element,
            app.launchArguments.contains(where: { $0.hasPrefix("UICTContentSizeCategoryAccessibility") })
        else { return false }
        let scan = [AccessibilityID.Home.scan, AccessibilityID.Grid.scan].lazy.map { app.buttons[$0] }.first {
            $0.exists
        }
        guard let scan else { return false }
        let barTop = scan.frame.minY - barTopPadding
        return element.frame.minY < barTop && element.frame.maxY > barTop
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
    // iOS 27's audit reports Trash's Liquid Glass buttons as low contrast even with near-black text on near-white glass
    // (about 15:1 measured in the audit's own element screenshot, Trash redesign evidence): the bottom bar's three and
    // the toolbar's Select/Cancel pill (CI run 42494009425). Ben accepted the bar's three on 2026-11-08 (#59);
    // `trash.select` joined them by the executor's ruling under Ben's standing call to exempt to unblock while tracked
    // (#59 lists it). Only contrast, and only these four buttons, matched by identifier; any other element, and any
    // contrast issue with no element, still fails.
    { _, issue in
        guard issue.auditType == .contrast, let element = issue.element else { return false }
        let glassButtons = [
            AccessibilityID.Trash.emptyTrash, AccessibilityID.Trash.deleteSelected,
            AccessibilityID.TrashViewer.deleteNow, AccessibilityID.Trash.select,
        ]
        return glassButtons.contains(element.identifier)
    },
    // Trash's glass bottom bar, reported with no element: on the Trash grid the bar sits in BottomBarLayout's
    // .safeAreaInset, where the audit can't resolve the glass buttons to elements, so it reports their text as low
    // contrast and as inaccessible text (hiding Empty Trash clears it). The viewer's .overlay bar, the same buttons,
    // resolves fine. The real fix is to present the bar as an overlay (issue #59). Ben accepted this on 2026-11-08.
    // Only contrast and element detection, only with no element, and only while the Trash screen is showing;
    // element-less issues on every other screen still fail.
    { app, issue in
        [.contrast, .elementDetection].contains(issue.auditType) && issue.element == nil
            && app.header("Trash").exists
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
        let ignored = ignoredIssues.contains { $0(app, issue) }
        if !ignored { attachDetails(of: issue, in: app) }
        return ignored
    }
}

/// The audit's own failure names only the element's class ("SwiftUI.AccessibilityNode"), which can't tell a CI-only
/// failure apart. Attaches what the exemptions match on: the element's label, identifier and frame, the window and the
/// Scan bar's top edge.
@MainActor
private func attachDetails(of issue: XCUIAccessibilityAuditIssue, in app: XCUIApplication) {
    let scan = [AccessibilityID.Home.scan, AccessibilityID.Grid.scan].lazy.map { app.buttons[$0] }.first { $0.exists }
    let lines = [
        "type: \(issue.auditType.rawValue) · \(issue.compactDescription)",
        "detail: \(issue.detailedDescription)",
        "element: \(issue.element.map { "'\($0.label)' id '\($0.identifier)' frame \($0.frame)" } ?? "none")",
        "window: \(app.windows.firstMatch.frame)",
        "scan: \(scan.map { "\($0.frame), bar top \($0.frame.minY - barTopPadding)" } ?? "none")",
    ]
    let attachment = XCTAttachment(string: lines.joined(separator: "\n"))
    attachment.name = "Audit issue"
    attachment.lifetime = .keepAlways
    XCTContext.runActivity(named: "Audit issue: \(issue.compactDescription)") { $0.add(attachment) }
}
