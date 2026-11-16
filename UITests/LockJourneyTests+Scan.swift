import Core
import XCTest

/// Scans and the lock: what a Scan request from outside shows when the library locked again over something the app had
/// presented, and a review left open past the relock time. The request is sent to the running app (`RequestURL`), as
/// the Scan control or the Action button would send it.
extension LockJourneyTests {
    /// Search is up when the library locks again. A Scan request closes it behind the cover and opens the camera:
    /// nothing of the library shows on the way, in the camera, in review or after.
    func testScanRequestOverSearchAfterARelockShowsOnlyTheScan() throws {
        let app = relockingApp(authenticator: "succeedsOnce")
        let homeField = app.buttons[AccessibilityID.Home.search]
        XCTAssertTrue(homeField.satisfies("isHittable == true", within: 5))
        homeField.tap()
        XCTAssertTrue(app.textFields[AccessibilityID.Search.field].appears(within: 5))

        leaveAndReturn(app)
        XCTAssertTrue(app.buttons[AccessibilityID.Lock.unlock].appears(within: 5))
        assertLibraryUnreachable(in: app)

        try scanFromOutsideAndDiscard(in: app)
    }

    /// The same with the system share sheet up over a scan's viewer: the sheet names the scan and shows its first page,
    /// and it is gone, behind the cover, before the camera shows.
    func testScanRequestOverAShareSheetAfterARelockShowsOnlyTheScan() throws {
        let app = relockingApp(authenticator: "succeedsOnce")
        let all = app.buttons[AccessibilityID.Home.allRow]
        XCTAssertTrue(all.satisfies("isHittable == true", within: 5))
        all.tap()
        let tile = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Grid.tilePrefix)
        ).firstMatch
        XCTAssertTrue(tile.appears(within: 5))
        tile.tap()
        let share = app.buttons[AccessibilityID.Viewer.share]
        XCTAssertTrue(share.appears(within: 5))
        share.tap()
        // UIKit's own identifier, not API (see ExportJourneyTests).
        let sheet = app.otherElements["ActivityListView"]
        XCTAssertTrue(sheet.appears(within: 10))

        leaveAndReturn(app)
        XCTAssertTrue(app.buttons[AccessibilityID.Lock.unlock].appears(within: 5))
        assertLibraryUnreachable(in: app)

        try scanFromOutsideAndDiscard(in: app)
        XCTAssertFalse(sheet.exists, "the share sheet closed with the viewer")
    }

    /// A scan started while unlocked and left in review is covered like the rest once the library locks again; Unlock
    /// returns to the review as it was (ruling R10).
    func testAReviewLeftOpenIsCoveredAfterARelock() {
        let app = relockingApp(authenticator: "cancelsSecond")
        scanOnePage(in: app)
        let save = app.buttons[AccessibilityID.Review.save]

        leaveAndReturn(app)
        let unlock = app.buttons[AccessibilityID.Lock.unlock]
        XCTAssertTrue(unlock.appears(within: 5))
        assertLibraryUnreachable(in: app)
        XCTAssertFalse(save.exists, "the review is behind the cover")
        XCTAssertFalse(app.descendants(matching: .any)[AccessibilityID.Review.title].exists)

        unlock.tap()
        XCTAssertTrue(cover(in: app).disappears(within: 5))
        XCTAssertTrue(save.satisfies("isHittable == true", within: 5), "the review is back")
    }

    // MARK: Steps

    /// Locked, unlocked by the first Face ID, and locking again after any time away; the fake camera has one page.
    private func relockingApp(authenticator: String) -> XCUIApplication {
        let app = lockedApp(authenticator: authenticator, ["-LockAfter", "0", "-FakeCamera", "1", "-FakeReader"])
        XCTAssertTrue(
            app.buttons[AccessibilityID.Home.collectionRow(.wallet)].satisfies("isHittable == true", within: 5))
        return app
    }

    /// Sends a Scan request to the locked app: the camera and then the review show, with nothing of the library in
    /// reach, and discarding ends at the cover.
    private func scanFromOutsideAndDiscard(in app: XCUIApplication) throws {
        XCUIDevice.shared.system.open(try XCTUnwrap(RequestURL.make("scan")))
        reviewTheRequestedScan(in: app)
        assertNothingOfTheLibrary(in: app)

        app.buttons[AccessibilityID.Review.close].tap()
        let alert = app.alerts["Discard this scan?"]
        XCTAssertTrue(alert.appears(within: 5))
        alert.buttons["Discard"].tap()
        XCTAssertTrue(app.buttons[AccessibilityID.Review.save].disappears(within: 10))
        XCTAssertTrue(app.buttons[AccessibilityID.Lock.unlock].appears(within: 5))
        assertLibraryUnreachable(in: app)
    }
}
