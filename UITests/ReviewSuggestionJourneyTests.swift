import Core
import XCTest

/// Review with the model's suggestion (M6, M11): the slim card while it reads, filled when the suggestion lands, and
/// the full sheet when the card is opened, the model is too slow, or it isn't available. `-Suggestions arrives` answers
/// City Pharmacy after 0.3 s; `slow` never answers, so the 5 s wait passes.
@MainActor
final class ReviewSuggestionJourneyTests: XCTestCase {
    private typealias Review = AccessibilityID.Review

    /// Longer than the 5 s wait for a suggestion, with room for a slow simulator.
    private static let pastTheWait: TimeInterval = 15

    override func setUp() {
        continueAfterFailure = false
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

    /// The suggestion fills the card and turns Save on; Save files the scan under its suggested title and collection.
    func testSuggestionArrivesAndSaves() {
        let app = launchApp(["-FakeCamera", "1", "-FakeReader", "-Suggestions", "arrives"])
        scanOnePage(in: app)
        waitForSuggestion(in: app)
        let save = app.buttons[Review.save]
        XCTAssertTrue(save.satisfies("isEnabled == true", within: 5))
        XCTAssertEqual(save.label, "Save")
        save.tap()

        XCTAssertTrue(save.disappears(within: 10))
        let row = app.buttons[AccessibilityID.Home.collectionRow(.receipts)]
        XCTAssertTrue(row.satisfies("exists == true AND label CONTAINS '1'", within: 5), row.label)
        row.tap()
        let tile = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Grid.tilePrefix)
        ).firstMatch
        XCTAssertTrue(tile.appears(within: 5))
        XCTAssertTrue(tile.label.contains("City Pharmacy receipt"), tile.label)
    }

    /// Tapping the card opens the full sheet, filled with the suggestion.
    func testTapCardOpensSheet() {
        let app = launchApp(["-FakeCamera", "1", "-FakeReader", "-Suggestions", "arrives"])
        scanOnePage(in: app)
        waitForSuggestion(in: app)
        app.buttons[Review.card].tap()

        let collection = app.descendants(matching: .any)[Review.collection]
        XCTAssertTrue(collection.satisfies("exists == true AND value == %@", "Receipts", within: 5))
        let field = app.descendants(matching: .any)[Review.titleField]
        XCTAssertTrue(field.satisfies("exists == true AND value == %@", "City Pharmacy receipt", within: 5))
        XCTAssertFalse(app.buttons[Review.card].exists)
        XCTAssertEqual(app.buttons[Review.save].label, "Save to Receipts")
    }

    /// The model never answers: once the wait passes, the card grows into the sheet, which asks for a collection.
    func testSlowGrowsIntoSheet() {
        let app = launchApp(["-FakeCamera", "1", "-FakeReader", "-Suggestions", "slow"])
        scanOnePage(in: app)
        let card = app.buttons[Review.card]
        XCTAssertTrue(card.appears(within: 5))
        XCTAssertEqual(card.label, "Reading your scan…")
        XCTAssertFalse(app.buttons[Review.save].isEnabled)

        let collection = app.descendants(matching: .any)[Review.collection]
        XCTAssertTrue(
            collection.satisfies("exists == true AND value == %@", "Choose a collection", within: Self.pastTheWait))
        XCTAssertFalse(card.exists)
        let field = app.descendants(matching: .any)[Review.titleField]
        XCTAssertTrue(field.satisfies("value == %@", "City Pharmacy", within: 5), "the title from the text")
    }

    /// No model: the full sheet at once, as before Apple Intelligence.
    func testUnavailableShowsSheet() {
        let app = launchApp(["-FakeCamera", "1", "-FakeReader", "-Suggestions", "unavailable"])
        scanOnePage(in: app)
        XCTAssertTrue(app.descendants(matching: .any)[Review.collection].appears(within: 5))
        XCTAssertFalse(app.buttons[Review.card].exists)
        assertIdentifiers(Review.all, in: app)
    }

    // MARK: Steps

    /// The card shows the suggestion: "City Pharmacy receipt" in Receipts.
    private func waitForSuggestion(in app: XCUIApplication, line: UInt = #line) {
        let card = app.buttons[Review.card]
        XCTAssertTrue(
            card.satisfies("label == %@", "City Pharmacy receipt, Receipts · kept 3 months", within: 10),
            card.label,
            line: line)
    }

    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
