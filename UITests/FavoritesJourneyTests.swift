import Core
import XCTest

/// Favourites end to end: the viewer's heart, Home's Favorites row and the Favorites grid (Plan 4, Task 5). Seeded
/// scans are "Sample scan 1" (newest) to "Sample scan 6"; `-SeedFavorites n` makes the first n favourites, in order.
@MainActor
final class FavoritesJourneyTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testHeartingAScanPutsItOnHome() {
        let app = seededApp()
        XCTAssertFalse(favoriteCards(in: app).firstMatch.exists, "no favourites yet, so no row")

        openFromAllScans("Sample scan 2", in: app)
        let heart = app.buttons[AccessibilityID.Viewer.favorite]
        XCTAssertEqual(heart.label, "Add to Favorites")
        heart.tap()
        XCTAssertTrue(heart.satisfies("label == %@", "Remove from Favorites", within: 5))
        XCTAssertTrue(heart.isSelected)

        goBack(in: app)
        XCTAssertTrue(tile("Sample scan 2", in: app).satisfies("label ENDSWITH %@", ", favorite", within: 5))
        goBack(in: app)
        XCTAssertTrue(favoriteCards(in: app).firstMatch.satisfies("label == %@", "Sample scan 2", within: 5))
        XCTAssertEqual(favoriteCards(in: app).count, 1)
        XCTAssertFalse(app.buttons[AccessibilityID.Home.favoritesLink].exists, "one favourite: a plain header")
    }

    /// Review Focus 1: a favourite goes to Trash with its heart and comes back as a favourite.
    func testFavoriteSurvivesTrashAndRestore() {
        let app = seededApp()
        openFromAllScans("Sample scan 2", in: app)
        app.buttons[AccessibilityID.Viewer.favorite].tap()
        XCTAssertTrue(
            app.buttons[AccessibilityID.Viewer.favorite].satisfies(
                "label == %@", "Remove from Favorites", within: 5))

        app.buttons[AccessibilityID.Viewer.trash].tap()
        let confirm = app.buttons.matching(
            NSPredicate(format: "label == %@ AND identifier != %@", "Move to Trash", AccessibilityID.Viewer.trash)
        ).firstMatch
        XCTAssertTrue(confirm.appears(within: 5))
        confirm.tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Viewer.header].disappears(within: 5))
        goBack(in: app)
        XCTAssertFalse(favoriteCards(in: app).firstMatch.exists, "in Trash, it isn't on Home")

        let trashRow = app.buttons[AccessibilityID.Home.trashRow]
        XCTAssertTrue(trashRow.satisfies("label == %@", "Trash, 1", within: 5), trashRow.label)
        trashRow.tap()
        let trashTile = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Trash.tilePrefix)
        ).firstMatch
        XCTAssertTrue(trashTile.appears(within: 5))
        XCTAssertTrue(trashTile.label.hasSuffix(", favorite"), trashTile.label)
        trashTile.tap()
        let restore = app.buttons[AccessibilityID.TrashViewer.restore]
        XCTAssertTrue(restore.appears(within: 5))
        restore.tap()
        XCTAssertTrue(app.staticTexts["Trash is empty"].appears(within: 5))
        goBack(in: app)

        XCTAssertTrue(favoriteCards(in: app).firstMatch.satisfies("label == %@", "Sample scan 2", within: 5))
    }

    func testFavoritesLinkOpensTheGrid() {
        let app = seededApp(favorites: 3)
        let link = app.buttons[AccessibilityID.Home.favoritesLink]
        XCTAssertTrue(link.appears(within: 5))
        XCTAssertEqual(cardTitles(in: app), ["Sample scan 1", "Sample scan 2", "Sample scan 3"])
        link.tap()
        XCTAssertTrue(app.header("Favorites").appears(within: 5))
        XCTAssertEqual(tileTitles(in: app), ["Sample scan 1", "Sample scan 2", "Sample scan 3"])
    }

    /// B8: a new favourite goes last, on Home and in Favorites.
    func testNewFavoriteGoesLast() {
        let app = seededApp(favorites: 3)
        XCTAssertTrue(app.buttons[AccessibilityID.Home.favoritesLink].appears(within: 5))
        openFromAllScans("Sample scan 5", in: app)
        app.buttons[AccessibilityID.Viewer.favorite].tap()
        XCTAssertTrue(
            app.buttons[AccessibilityID.Viewer.favorite].satisfies(
                "label == %@", "Remove from Favorites", within: 5))
        goBack(in: app)
        goBack(in: app)

        XCTAssertTrue(favoriteCards(in: app).element(boundBy: 3).appears(within: 5))
        XCTAssertEqual(cardTitles(in: app).last, "Sample scan 5")
        app.buttons[AccessibilityID.Home.favoritesLink].tap()
        XCTAssertTrue(app.header("Favorites").appears(within: 5))
        XCTAssertEqual(tileTitles(in: app).last, "Sample scan 5")
    }

    // MARK: Steps

    /// Six seeded scans, every one landed: Wallet holds scans 1 and 6.
    private func seededApp(favorites: Int = 0) -> XCUIApplication {
        let favoriteFlags = favorites > 0 ? ["-SeedFavorites", "\(favorites)"] : []
        let app = launchApp(["-SeedScans", "6", "-FixedDate", "2026-10-12"] + favoriteFlags)
        waitForSeeding(of: app.buttons[AccessibilityID.Home.collectionRow(.wallet)], count: 2)
        return app
    }

    /// From Home, All Scans, then the scan titled `title`, in the viewer.
    private func openFromAllScans(_ title: String, in app: XCUIApplication) {
        let all = app.buttons[AccessibilityID.Home.allRow]
        XCTAssertTrue(all.appears(within: 5))
        all.tap()
        let tile = tile(title, in: app)
        XCTAssertTrue(tile.appears(within: 5))
        tile.tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.Viewer.header].appears(within: 5))
    }

    private func goBack(in app: XCUIApplication) {
        let back = app.buttons[AccessibilityID.Grid.back]
        XCTAssertTrue(back.appears(within: 5))
        back.tap()
    }

    private func tile(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", AccessibilityID.Grid.tilePrefix, "\(title),"
            )
        ).firstMatch
    }

    private func tileTitles(in app: XCUIApplication) -> [String] {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Grid.tilePrefix))
            .allElementsBoundByIndex.map { $0.label.components(separatedBy: ",")[0] }
    }

    private func favoriteCards(in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Home.favoritePrefix))
    }

    private func cardTitles(in app: XCUIApplication) -> [String] {
        favoriteCards(in: app).allElementsBoundByIndex.map(\.label)
    }
}
