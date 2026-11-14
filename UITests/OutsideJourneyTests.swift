import Core
import XCTest

/// Requests from outside the app (Plan 6 §7, M9), sent at launch by `-Request` as the Scan control, Shortcuts, Siri or
/// a Spotlight result would send them (M15). Seeded scans are "Sample scan 1" (newest) onwards, cycling Wallet,
/// Receipts, Notes, Documents, Throwaways; Receipts' scans carry the hidden word "receipt".
@MainActor
final class OutsideJourneyTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testScanRequestOpensCamera() {
        let app = launchApp(["-Request", "scan", "-FakeCamera", "1", "-FakeReader", "-FixedDate", "2026-10-12"])
        let finish = app.buttons[AccessibilityID.Camera.fakeFinish]
        XCTAssertTrue(finish.appears(within: 10), "the camera opens without a tap on Scan")
        finish.tap()

        let save = app.buttons[AccessibilityID.Review.save]
        XCTAssertTrue(save.appears(within: 5))
        app.descendants(matching: .any)[AccessibilityID.Review.collection].tap()
        let receipts = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Receipts'")).firstMatch
        XCTAssertTrue(receipts.appears(within: 5))
        receipts.tap()
        save.tap()

        // Started from Home, so it lands there.
        XCTAssertTrue(save.disappears(within: 10))
        let row = app.buttons[AccessibilityID.Home.collectionRow(.receipts)]
        XCTAssertTrue(row.satisfies("exists == true AND label CONTAINS '1'", within: 5), row.label)
        XCTAssertTrue(row.satisfies("isHittable == true", within: 5))
    }

    func testScanRequestDuringWelcomeOpensCameraAfter() {
        let app = launchApp([
            "-ShowWelcome", "-Notifications", "authorized", "-Request", "scan", "-FakeCamera", "1",
        ])
        let continueButton = app.buttons[AccessibilityID.Welcome.continue]
        XCTAssertTrue(continueButton.appears(within: 5))
        let finish = app.buttons[AccessibilityID.Camera.fakeFinish]
        // Launch has finished (Scan is enabled under the sheet) and the camera still waits for the welcome.
        XCTAssertTrue(app.buttons[AccessibilityID.Home.scan].satisfies("isEnabled == true", within: 5))
        XCTAssertFalse(finish.exists, "no camera during the welcome")

        continueButton.tap()

        XCTAssertTrue(finish.appears(within: 10), "the camera opens once the welcome closes")
    }

    func testSearchRequestShowsResults() throws {
        let app = launchApp(["-SeedScans", "5", "-FixedDate", "2026-10-12", "-Request", "search:receipt"])
        let field = app.textFields[AccessibilityID.Search.field]
        XCTAssertTrue(field.appears(within: 10))
        XCTAssertEqual(field.value as? String, "receipt")
        let results = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Search.resultPrefix))
        let first = results.firstMatch
        XCTAssertTrue(first.satisfies("label BEGINSWITH %@", "Sample scan 2, Receipts", within: 5), first.label)
        XCTAssertEqual(results.count, 1)
    }

    func testOpenRequestShowsTheViewer() {
        let app = launchApp(["-SeedScans", "3", "-FixedDate", "2026-10-12", "-Request", "open:1"])
        let header = app.descendants(matching: .any)[AccessibilityID.Viewer.header]
        XCTAssertTrue(header.appears(within: 10))
        XCTAssertTrue(header.label.hasPrefix("Sample scan 1"), header.label)

        // Pushed over Home: back returns there.
        app.buttons[AccessibilityID.Viewer.back].tap()
        XCTAssertTrue(app.buttons[AccessibilityID.Home.scan].satisfies("isHittable == true", within: 5))
    }
}
