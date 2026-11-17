import Core
import XCTest

/// The library lock (library-lock design): `-Lock on` turns it on for the run and `-Authenticator` scripts Face ID's
/// answers, so no system prompt shows. Three seeded scans (Wallet, Receipts, Notes).
///
/// The cover has the identifier `lock.cover` twice: over the navigation stack and in the shield, the window above the
/// app's own. While the shield is up the app's window is out of the accessibility tree, so XCUITest sees one cover, the
/// shield's (with Unlock once Face ID was cancelled or failed); under a Scan request's capture layer it sees none.
/// The journeys of scans and the lock are in `LockJourneyTests+Scan.swift`.
@MainActor
final class LockJourneyTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testFaceIDSucceedsShowsHome() {
        let app = lockedApp(authenticator: "succeeds")
        XCTAssertTrue(
            app.buttons[AccessibilityID.Home.collectionRow(.wallet)].satisfies("isHittable == true", within: 5))
        XCTAssertTrue(cover(in: app).disappears(within: 5))
    }

    func testCancelledFaceIDKeepsTheCoverAndUnlockAsksAgain() {
        let app = lockedApp(authenticator: "cancels")
        let unlock = app.buttons[AccessibilityID.Lock.unlock]
        XCTAssertTrue(unlock.appears(within: 5))
        assertIdentifiers(AccessibilityID.Lock.all, in: app)
        assertLibraryUnreachable(in: app)

        // Still cancelled: the cover stays.
        unlock.tap()
        XCTAssertTrue(unlock.appears(within: 5))
        XCTAssertTrue(cover(in: app).exists)
        assertLibraryUnreachable(in: app)
    }

    /// The shield's Unlock button unlocks once Face ID answers yes.
    func testUnlockOpensTheLibraryWhenFaceIDSucceeds() {
        let app = lockedApp(authenticator: "cancelsOnce")
        let unlock = app.buttons[AccessibilityID.Lock.unlock]
        XCTAssertTrue(unlock.appears(within: 5))

        unlock.tap()
        XCTAssertTrue(cover(in: app).disappears(within: 5))
        XCTAssertTrue(
            app.buttons[AccessibilityID.Home.collectionRow(.wallet)].satisfies("isHittable == true", within: 5))
    }

    /// A Scan request never waits for, triggers or counts as an unlock: with Face ID ready to say yes, none is asked,
    /// the saved scan stays behind the cover with Unlock, and only Unlock opens the library.
    func testScanRequestWhileLockedSavesBehindTheCover() {
        let app = lockedApp(authenticator: "succeeds", ["-Request", "scan", "-FakeCamera", "1", "-FakeReader"])
        reviewTheRequestedScan(in: app)
        app.descendants(matching: .any)[AccessibilityID.Review.collection].tap()
        let receipts = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Receipts'")).firstMatch
        XCTAssertTrue(receipts.appears(within: 5))
        receipts.tap()
        app.buttons[AccessibilityID.Review.save].tap()

        XCTAssertTrue(app.buttons[AccessibilityID.Review.save].disappears(within: 10))
        let unlock = app.buttons[AccessibilityID.Lock.unlock]
        XCTAssertTrue(unlock.appears(within: 5))
        assertLibraryUnreachable(in: app)

        unlock.tap()
        XCTAssertTrue(cover(in: app).disappears(within: 5))
        let row = app.buttons[AccessibilityID.Home.collectionRow(.receipts)]
        XCTAssertTrue(row.satisfies("isHittable == true AND label CONTAINS '2'", within: 5), row.label)
    }

    func testScanRequestWhileLockedDiscardsBehindTheCover() {
        let app = lockedApp(authenticator: "succeeds", ["-Request", "scan", "-FakeCamera", "1", "-FakeReader"])
        reviewTheRequestedScan(in: app)
        app.buttons[AccessibilityID.Review.close].tap()
        let alert = app.alerts["Discard this scan?"]
        XCTAssertTrue(alert.appears(within: 5))
        alert.buttons["Discard"].tap()

        XCTAssertTrue(app.buttons[AccessibilityID.Review.save].disappears(within: 10))
        let unlock = app.buttons[AccessibilityID.Lock.unlock]
        XCTAssertTrue(unlock.appears(within: 5))
        assertLibraryUnreachable(in: app)

        unlock.tap()
        XCTAssertTrue(cover(in: app).disappears(within: 5))
        XCTAssertTrue(
            app.buttons[AccessibilityID.Home.collectionRow(.wallet)].satisfies("isHittable == true", within: 5))
    }

    /// A cancelled Face ID drops a waiting search: Search never opens.
    func testSearchRequestWhileLockedNeverOpensSearch() {
        let app = lockedApp(authenticator: "cancels", ["-Request", "search:pharmacy"])
        XCTAssertTrue(app.buttons[AccessibilityID.Lock.unlock].appears(within: 5))
        XCTAssertFalse(app.textFields[AccessibilityID.Search.field].appears(within: 2), "Search never opens")
        assertLibraryUnreachable(in: app)
    }

    /// Away at least `-LockAfter` (0 s: any time away counts, so no test waits on the clock), the library locks again,
    /// and the second Face ID try (cancelled) leaves the cover with Unlock.
    func testReturningAfterTheRelockTimeLocksAgain() {
        let app = lockedApp(authenticator: "succeedsOnce", ["-LockAfter", "0"])
        XCTAssertTrue(
            app.buttons[AccessibilityID.Home.collectionRow(.wallet)].satisfies("isHittable == true", within: 5))

        leaveAndReturn(app)
        XCTAssertTrue(app.buttons[AccessibilityID.Lock.unlock].appears(within: 5))
        assertLibraryUnreachable(in: app)
    }

    /// The shield covers Search's cover too: back after the relock time, Search's field and results are out of reach.
    func testReturningToSearchAfterTheRelockTimeCoversSearch() {
        let app = lockedApp(authenticator: "succeedsOnce", ["-LockAfter", "0"])
        let homeField = app.buttons[AccessibilityID.Home.search]
        XCTAssertTrue(homeField.satisfies("isHittable == true", within: 5))
        homeField.tap()
        XCTAssertTrue(app.textFields[AccessibilityID.Search.field].appears(within: 5))

        leaveAndReturn(app)
        XCTAssertTrue(app.buttons[AccessibilityID.Lock.unlock].appears(within: 5))
        assertLibraryUnreachable(in: app)
    }

    /// Back within the relock time, the library is as it was.
    func testReturningWithinTheRelockTimeKeepsTheLibraryOpen() {
        let app = lockedApp(authenticator: "succeedsOnce", ["-LockAfter", "300"])
        let wallet = app.buttons[AccessibilityID.Home.collectionRow(.wallet)]
        XCTAssertTrue(wallet.satisfies("isHittable == true", within: 5))

        leaveAndReturn(app)
        XCTAssertTrue(cover(in: app).disappears(within: 5))
        XCTAssertTrue(wallet.satisfies("isHittable == true", within: 5))
    }

    /// Turning the lock on asks Face ID (scripted yes); on, the subtitle says when it asks and the footer adds the
    /// backup advice. Off again, the advice goes.
    func testSettingsSwitchTurnsTheLockOnAndOff() throws {
        let app = launchApp(["-SeedScans", "3", "-Authenticator", "succeeds"])
        let lock = openSettingsLockSwitch(in: app)
        XCTAssertEqual(lock.value as? String, "0")
        XCTAssertTrue(lock.label.contains("Asks when you open the app"), lock.label)
        let advice = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Advanced Data Protection'"))
            .firstMatch
        XCTAssertFalse(advice.exists)

        lock.tap()
        XCTAssertTrue(lock.satisfies("value == '1'", within: 5))
        XCTAssertTrue(advice.appears(within: 5))
        try audit(app)

        lock.tap()
        XCTAssertTrue(lock.satisfies("value == '0'", within: 5))
        XCTAssertTrue(advice.disappears(within: 5))
    }

    /// With no passcode on the phone there is nothing to lock with: the switch is disabled and says why.
    func testSettingsSwitchIsDisabledWithoutAPasscode() throws {
        let app = launchApp(["-SeedScans", "3", "-Authenticator", "none"])
        let lock = openSettingsLockSwitch(in: app)
        XCTAssertFalse(lock.isEnabled)
        XCTAssertEqual(lock.value as? String, "0")
        XCTAssertTrue(lock.label.contains("Set a passcode in iPhone Settings to use this"), lock.label)
        try audit(app)
    }

    func testAuditTheCover() throws {
        let app = lockedApp(authenticator: "cancels")
        XCTAssertTrue(app.buttons[AccessibilityID.Lock.unlock].appears(within: 5))
        try audit(app)
    }

    func testAuditAtLargestTextTheCover() throws {
        let app = lockedApp(authenticator: "cancels", largestText: true)
        XCTAssertTrue(app.buttons[AccessibilityID.Lock.unlock].appears(within: 5))
        try audit(app)
    }

    func testAuditAtLargestTextSettings() throws {
        let app = launchApp(["-SeedScans", "3", "-Authenticator", "succeeds", "-Lock", "on"], largestText: true)
        let lock = openSettingsLockSwitch(in: app)
        XCTAssertEqual(lock.value as? String, "1")
        try audit(app)
    }

    // MARK: Steps

    /// The app with the lock on, three seeded scans and Face ID answering as `authenticator` says.
    func lockedApp(
        authenticator: String, _ flags: [String] = [], largestText: Bool = false
    ) -> XCUIApplication {
        launchApp(
            ["-SeedScans", "3", "-Lock", "on", "-Authenticator", authenticator] + flags, largestText: largestText)
    }

    /// The cover XCUITest can see: the shield's while it is up, the stack's otherwise (see the type's note).
    func cover(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: AccessibilityID.Lock.cover).firstMatch
    }

    /// The camera opens with no tap on Scan and no Face ID, and the page reaches review.
    func reviewTheRequestedScan(in app: XCUIApplication) {
        let finish = app.buttons[AccessibilityID.Camera.fakeFinish]
        XCTAssertTrue(finish.appears(within: 10), "the camera opens though the library is locked")
        finish.tap()
        XCTAssertTrue(app.buttons[AccessibilityID.Review.save].appears(within: 5))
    }

    /// To the Home Screen and back.
    func leaveAndReturn(_ app: XCUIApplication) {
        XCUIDevice.shared.press(.home)
        let left = app.satisfies(within: 10) { ($0 as? XCUIApplication)?.state != .runningForeground }
        XCTAssertTrue(left, "the app left the foreground")
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }

    /// Nothing of the library is in the accessibility tree: no Home, grid, viewer or Search element, so neither
    /// VoiceOver nor a tap reaches it. One read of the tree, so it costs one query, not one per identifier.
    func assertLibraryUnreachable(
        in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(cover(in: app).exists, "the cover is up", file: file, line: line)
        assertNothingOfTheLibrary(in: app, file: file, line: line)
    }

    /// The same, where the cover itself may be out of the tree: under a Scan request's camera or review.
    func assertNothingOfTheLibrary(
        in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line
    ) {
        let libraryPrefixes = ["home.", "grid.", "viewer.", "search.", "settings."]
        do {
            let elements = flattened(try app.snapshot())
            let reachable = elements.map(\.identifier).filter { identifier in
                libraryPrefixes.contains { identifier.hasPrefix($0) }
            }
            XCTAssertEqual(reachable, [], "reachable while locked", file: file, line: line)
            // Seeded scans' titles, and the scan a Scan request saves while locked.
            let titles = elements.map(\.label).filter { $0.contains("Sample scan") || $0.contains("City Pharmacy") }
            XCTAssertEqual(titles, [], "a scan's title is readable while locked", file: file, line: line)
        } catch {
            XCTFail("the accessibility tree could not be read: \(error)", file: file, line: line)
        }
    }

    private func flattened(_ element: XCUIElementSnapshot) -> [XCUIElementSnapshot] {
        [element] + element.children.flatMap(flattened)
    }

    private func openSettingsLockSwitch(in app: XCUIApplication) -> XCUIElement {
        let gear = app.buttons[AccessibilityID.Home.settings]
        XCTAssertTrue(gear.satisfies("isHittable == true", within: 5))
        gear.tap()
        assertIdentifiers(AccessibilityID.Settings.all + [AccessibilityID.Grid.back], in: app)
        let lock = app.switches[AccessibilityID.Settings.lockSwitch]
        if !lock.isHittable { dragUp(app) }
        XCTAssertTrue(lock.satisfies("isHittable == true", within: 5))
        return lock
    }

    /// Scrolls up by a set distance: a slow drag held at its end, so no momentum carries on. A swipe stops wherever its
    /// momentum ends, and on CI that left Settings' first row half under the header bar, where the audit reads the
    /// bar's blur as low contrast ("Collections" at y 73, runs on 5555b3f and 04024c3).
    private func dragUp(_ app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
    }
}
