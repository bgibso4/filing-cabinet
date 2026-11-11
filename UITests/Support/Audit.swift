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
    // The iOS 27 glass misread is reported in either of two forms for the same control, and which one varies from run
    // to run and simulator to simulator: as an issue with no element, or resolved to the glass control itself. On
    // 2026-11-10 (test-runs PR) the grid's select-mode pill was reported as `grid.select` in 5 runs and with no element
    // in 2, on the same simulator; the viewer's dark bars with no element on one simulator and as the header's title on
    // another. Each existing exemption covered only the form first seen, so these audits passed or failed by luck
    // (CI passed; this Mac failed). The two below cover the other form: the grid's Cancel pill (as Trash's
    // `trash.select`) and the viewer's dark glass bars (as `dark-viewer-header`), whose text and icons read clearly in
    // the audit's own screenshots. Added under Ben's standing call to exempt the glass misread to unblock while tracked
    // (#59); awaiting his review.
    // Only contrast, and only the grid's Select pill while it reads Cancel.
    AuditExemption(name: "grid-select-pill") { app, issue in
        guard issue.auditType == .contrast, issue.element?.identifier == AccessibilityID.Grid.select else {
            return false
        }
        return app.buttons[AccessibilityID.Grid.select].label == "Cancel"
    },
    // At the largest text size Home's search field and Favorites row make it taller, so a collection label lands under
    // the opaque Scan pill. iOS 27's audit samples the pill's pixels and reports low contrast, in either of two forms
    // from run to run: with no element, or resolved to the row beneath the pill (label "2" or "Wallet" at y≈777 in
    // the 2026-11-10 and 11-11 whole-suite runs, which passed on retest). An equal-height invisible spacer reproduces
    // it, so it is the layout and not the field (#59). Ben accepted the misread on 2026-11-10 (plan 4, B13: no-element
    // form); the controller widened it to the element form on 2026-11-11 (final review I1), which Ben may narrow. #83,
    // the fade behind Scan, is the likely real fix.
    // Only contrast, only while Home shows with nothing over it (its Scan button hittable, and neither the camera-off
    // sheet nor Search up), and only with no element or an element whose frame meets the Scan pill's. A grid's Scan
    // button has its own identifier; any other issue on Home, and any element clear of the pill, still fails.
    AuditExemption(name: "home-scan-unresolved") { app, issue in
        guard issue.auditType == .contrast else { return false }
        let scan = app.buttons[AccessibilityID.Home.scan]
        let covered = [AccessibilityID.CameraOff.title, AccessibilityID.Search.field].contains {
            app.descendants(matching: .any)[$0].exists
        }
        guard scan.exists, scan.isHittable, !covered else { return false }
        return issue.element.map { $0.frame.intersects(scan.frame) } ?? true
    },
    // Home's favourite cards are mostly an image of the scanned page, and the contrast of a document's own printing is
    // out of the app's hands. The audit reports low contrast on a card (label 'Sample scan 1', the thumbnail plus its
    // title) though every text in it is black on white in the audit's own element screenshot; it happens at the default
    // text size too, and with realistic seeded pages (2026-11-10). Ben accepted this on 2026-11-10 (plan 4, B14; #59).
    // The element the audit resolves reports id '' (not the card's `Home.favoritePrefix` identifier), so it is matched
    // by position: only contrast, and only an element whose frame lies within a favourite card's frame (cards found by
    // that identifier prefix, as FavoritesJourneyTests does). Any other element, any other issue on a card, and
    // element-less issues still fail.
    AuditExemption(name: "home-favorite-card") { app, issue in
        guard issue.auditType == .contrast, let element = issue.element else { return false }
        let cards = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Home.favoritePrefix)
        ).allElementsBoundByIndex
        return cards.contains { $0.frame.insetBy(dx: -1, dy: -1).contains(element.frame) }
    },
    // Only contrast, only with no element, only in dark mode, and only while the viewer's header shows.
    AuditExemption(name: "dark-viewer-unresolved") { app, issue in
        guard issue.auditType == .contrast, issue.element == nil, XCUIDevice.shared.appearance == .dark else {
            return false
        }
        return app.descendants(matching: .any)[AccessibilityID.Viewer.header].exists
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
        // The label and frame show which form an exemption caught (no element, or the one it resolved to).
        let element =
            issue.element.map { "id '\($0.identifier)' · label '\($0.label)' · frame \($0.frame)" } ?? "id 'none'"
        note("Audit exemption used · \(exemption.name) · \(name(of: issue)) · \(element)")
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
