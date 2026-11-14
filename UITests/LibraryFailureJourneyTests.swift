import Core
import XCTest

/// When the library can't open (#40): the failure screen instead of Home, and Try again. Each test launches a new
/// process, as the failure happens at launch.
@MainActor
final class LibraryFailureJourneyTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testShowsTheScreenNotHome() throws {
        let app = launchApp(["-FailLibraryOpen"], fresh: true)

        XCTAssertTrue(app.staticTexts[AccessibilityID.LibraryFailure.title].appears(within: 5))
        XCTAssertEqual(app.staticTexts[AccessibilityID.LibraryFailure.title].label, "Your library couldn’t open")
        XCTAssertEqual(app.buttons[AccessibilityID.LibraryFailure.sendReport].label, "Send report")
        XCTAssertEqual(app.buttons[AccessibilityID.LibraryFailure.tryAgain].label, "Try again")
        assertIdentifiers(AccessibilityID.LibraryFailure.all, in: app)
        XCTAssertFalse(app.buttons[AccessibilityID.Home.scan].exists)
        attach(app, named: "library-failure")
        try audit(app)
    }

    func testTryAgainStaysWhenStillFailing() {
        let app = launchApp(["-FailLibraryOpen"], fresh: true)
        let tryAgain = app.buttons[AccessibilityID.LibraryFailure.tryAgain]
        XCTAssertTrue(tryAgain.appears(within: 5))

        tryAgain.tap()

        XCTAssertTrue(app.staticTexts[AccessibilityID.LibraryFailure.title].exists)
        XCTAssertTrue(tryAgain.isHittable)
        XCTAssertFalse(app.buttons[AccessibilityID.Home.scan].exists)
    }

    func testTryAgainOpensHome() {
        let app = launchApp(["-FailLibraryOpen", "once"], fresh: true)
        let tryAgain = app.buttons[AccessibilityID.LibraryFailure.tryAgain]
        XCTAssertTrue(tryAgain.appears(within: 5))

        tryAgain.tap()

        let scan = app.buttons[AccessibilityID.Home.scan]
        XCTAssertTrue(scan.satisfies("isEnabled == true", within: 5))
        XCTAssertFalse(app.staticTexts[AccessibilityID.LibraryFailure.title].exists)
    }

    /// A request from outside the app (here the Scan control's) is dropped: no camera over the failure screen, and none
    /// after a Try again that opens the library.
    func testRequestIsIgnored() {
        let app = launchApp(["-FailLibraryOpen", "once", "-Request", "scan", "-FakeCamera", "1"], fresh: true)
        let tryAgain = app.buttons[AccessibilityID.LibraryFailure.tryAgain]
        XCTAssertTrue(tryAgain.appears(within: 5))
        let finish = app.buttons[AccessibilityID.Camera.fakeFinish]
        XCTAssertFalse(finish.exists)
        XCTAssertTrue(app.staticTexts[AccessibilityID.LibraryFailure.title].exists, "the failure screen stays")

        tryAgain.tap()

        XCTAssertTrue(app.buttons[AccessibilityID.Home.scan].satisfies("isEnabled == true", within: 5))
        XCTAssertFalse(finish.appears(within: 2), "the dropped request doesn't open the camera later")
    }

    func testAuditAtLargestTextOfTheFailureScreen() throws {
        let app = launchApp(["-FailLibraryOpen"], largestText: true, fresh: true)
        XCTAssertTrue(app.buttons[AccessibilityID.LibraryFailure.tryAgain].appears(within: 5))
        XCTAssertTrue(app.buttons[AccessibilityID.LibraryFailure.tryAgain].isHittable)
        attach(app, named: "library-failure-ax")
        try audit(app)
    }

    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
