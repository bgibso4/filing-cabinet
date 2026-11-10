import Core
import XCTest

/// Issues the audit may ignore. Each entry needs a comment with the reason it is a false positive.
@MainActor
private let exemptions: [AuditExemption] = [
    // At the largest text size the list is taller than the screen, and a row's label can start in the last point
    // of the window (the audit found "Notes" at y 872.7 in an 874 pt window). That text is scrolled out of view
    // and sits under the Scan button, so the audit samples background pixels and reports low contrast.
    // Only contrast, only an element that begins within 2 pt of the window's bottom edge or below it.
    AuditExemption(name: "deep-text-under-scan") { app, issue in
        guard issue.auditType == .contrast, let element = issue.element else { return false }
        return element.frame.minY >= app.windows.firstMatch.frame.maxY - 2
    },
    // On iOS 27 the audit reports text as clipped on any floating sheet (any detent shorter than .large), even with the
    // text intact. Ben chose the mocks' compact camera-off sheet knowing this (2026-11-06). Only textClipped, and only
    // this sheet's three text elements, matched by identifier; any other screen's clipped text still fails.
    AuditExemption(name: "camera-off-sheet-clipped") { _, issue in
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
    AuditExemption(name: "dark-viewer-header") { _, issue in
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
    AuditExemption(name: "trash-glass-buttons") { _, issue in
        guard issue.auditType == .contrast, let element = issue.element else { return false }
        let glassButtons = [
            AccessibilityID.Trash.emptyTrash, AccessibilityID.Trash.deleteSelected,
            AccessibilityID.TrashViewer.deleteNow, AccessibilityID.Trash.select,
        ]
        return glassButtons.contains(element.identifier)
    },
    // Trash's glass bottom bar, reported with no element: on the Trash grid the audit can't resolve the glass buttons
    // to elements, so it reports their text as low contrast and as inaccessible text (hiding Empty Trash clears it).
    // The viewer's bar, the same buttons, resolves fine. Presenting the grid's bar as an overlay, as #59 proposed,
    // didn't change it (2026-11-10). Ben accepted this on 2026-11-08.
    // Only contrast and element detection, only with no element, and only while the Trash screen is showing;
    // element-less issues on every other screen still fail.
    AuditExemption(name: "trash-bar-unresolved") { app, issue in
        [.contrast, .elementDetection].contains(issue.auditType) && issue.element == nil
            && app.header("Trash").exists
    },
    // The same misread on a collection grid in select mode (#68): the audit reports low contrast with no element while
    // the glass Cancel pill and the Move to Trash bar show, and none once select mode ends (FC Speed iPhone 17,
    // 2026-11-09). Ben accepted this on 2026-11-10, as he did for Trash's pill (#59). Only contrast, only with no
    // element, and only while a grid's Select button reads Cancel; select mode's other issues still fail.
    AuditExemption(name: "grid-select-unresolved") { app, issue in
        guard issue.auditType == .contrast, issue.element == nil else { return false }
        let select = app.buttons[AccessibilityID.Grid.select]
        return select.exists && select.label == "Cancel"
    },
]

/// The only call site of `performAccessibilityAudit`. Audit types are listed explicitly, not left to the default.
@MainActor
func audit(_ app: XCUIApplication) throws {
    let types = auditedTypes.reduce(into: XCUIAccessibilityAuditType()) { $0.insert($1.type) }
    note("Audit exemptions declared · \(exemptions.map(\.name).joined(separator: ", "))")
    try app.performAccessibilityAudit(for: types) { issue in
        guard let exemption = exemptions.first(where: { $0.matches(app, issue) }) else {
            attachDetails(of: issue, in: app)
            return false
        }
        let id = issue.element?.identifier ?? "none"
        note("Audit exemption used · \(exemption.name) · \(name(of: issue)) · id '\(id)'")
        return true
    }
}

/// A step in the test results that only carries its title, for `make audit-report` to read.
@MainActor
private func note(_ title: String) {
    XCTContext.runActivity(named: title) { _ in }
}

/// The audit types checked, with the names the results report. .action and .parentChild are left out: they flag
/// SwiftUI's own container/action semantics, not our elements.
@MainActor
private let auditedTypes: [(type: XCUIAccessibilityAuditType, name: String)] = [
    (.contrast, "contrast"), (.elementDetection, "elementDetection"), (.hitRegion, "hitRegion"),
    (.sufficientElementDescription, "sufficientElementDescription"), (.dynamicType, "dynamicType"),
    (.textClipped, "textClipped"), (.trait, "trait"),
]

@MainActor
private func name(of issue: XCUIAccessibilityAuditIssue) -> String {
    auditedTypes.first { $0.type == issue.auditType }?.name ?? "type \(issue.auditType.rawValue)"
}

/// The audit's own failure names only the element's class ("SwiftUI.AccessibilityNode"), which can't tell a CI-only
/// failure apart. Names the issue in the activity's title (what `make audit-report` prints) and attaches what the
/// exemptions match on: the element's label, identifier and frame, the window and the Scan button's frame.
@MainActor
private func attachDetails(of issue: XCUIAccessibilityAuditIssue, in app: XCUIApplication) {
    let scan = [AccessibilityID.Home.scan, AccessibilityID.Grid.scan].lazy.map { app.buttons[$0] }.first { $0.exists }
    let lines = [
        "type: \(name(of: issue)) · \(issue.compactDescription)",
        "detail: \(issue.detailedDescription)",
        "element: \(issue.element.map { "'\($0.label)' id '\($0.identifier)' frame \($0.frame)" } ?? "none")",
        "window: \(app.windows.firstMatch.frame)",
        "scan: \(scan.map { "\($0.frame)" } ?? "none")",
    ]
    let attachment = XCTAttachment(string: lines.joined(separator: "\n"))
    attachment.name = "Audit issue"
    attachment.lifetime = .keepAlways
    let element =
        issue.element.map { "id '\($0.identifier)' · label '\($0.label)' · frame \($0.frame)" } ?? "no element"
    XCTContext.runActivity(named: "Audit issue · \(name(of: issue)) · \(element)") { $0.add(attachment) }
}
