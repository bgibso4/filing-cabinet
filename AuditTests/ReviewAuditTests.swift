import Core
import XCTest

/// Review: the full sheet with the fake reader, and the slim card with the model's suggestion (M6, M11).
@MainActor
final class ReviewAuditTests: XCTestCase {
    private typealias Review = AccessibilityID.Review

    override func setUp() {
        continueAfterFailure = false
    }

    func testAuditAtLargestTextOfReview() throws {
        let app = launchApp(["-FakeCamera", "1", "-FixedDate", "2026-10-12", "-FakeReader"], largestText: true)
        scanOnePage(in: app)
        waitForTitle("City Pharmacy", in: app)
        XCTAssertTrue(app.buttons[Review.save].isHittable)
        attachScreenshot(of: app, named: "review-sheet-ax")
        try audit(app)
    }

    /// At the largest text size the card puts Save under the title and line (12-03).
    func testAuditAtLargestTextOnTheCard() throws {
        let app = launchApp(["-FakeCamera", "1", "-FakeReader", "-Suggestions", "arrives"], largestText: true)
        scanOnePage(in: app)
        waitForSuggestion(in: app)
        attachScreenshot(of: app, named: "card-largest-text")
        try audit(app)
    }

    func testAuditOnTheCard() throws {
        let app = launchApp(["-FakeCamera", "1", "-FakeReader", "-Suggestions", "arrives"])
        scanOnePage(in: app)
        waitForSuggestion(in: app)
        attachScreenshot(of: app, named: "card")
        try audit(app)
    }

    /// A three-page scan read, Save still off with no collection; then with Documents chosen.
    func testAuditReview() throws {
        let app = launchApp(["-FakeCamera", "3", "-FixedDate", "2026-10-12", "-FakeReader"])
        scanOnePage(in: app)
        waitForTitle("City Pharmacy", in: app)
        XCTAssertFalse(app.buttons[Review.save].isEnabled)
        try audit(app)

        app.descendants(matching: .any)[Review.collection].tap()
        let documents = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Documents")).firstMatch
        XCTAssertTrue(documents.appears(within: 5))
        documents.tap()
        XCTAssertTrue(app.buttons[Review.save].satisfies("label == %@", "Save to Documents", within: 5))
        try audit(app)
    }

    // MARK: Steps

    private func waitForTitle(_ title: String, in app: XCUIApplication, line: UInt = #line) {
        let field = app.descendants(matching: .any)[Review.titleField]
        XCTAssertTrue(field.satisfies("value == %@", title, within: 10), "title", line: line)
    }

    private func waitForSuggestion(in app: XCUIApplication, line: UInt = #line) {
        let card = app.buttons[Review.card]
        XCTAssertTrue(
            card.satisfies("label == %@", "City Pharmacy Receipt, Receipts · kept 3 months", within: 10),
            card.label,
            line: line)
    }
}
