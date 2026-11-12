import Core
import Foundation
import Library
import Testing

@testable import ScreenModels
@testable import TestSupport

// MARK: - Favorites

private func favorite(_ title: String, order: Int?, _ collection: BuiltInCollection = .receipts, daysAgo: Int = 0)
    -> ScanSummary
{
    var made = scan(title, collection, daysAgo: daysAgo)
    made.favoriteOrder = order
    return made
}

@Test func favoritesGridShowsOnlyFavorites() {
    let grid = GridHarness(
        .favorites, [favorite("Kept", order: 0), scan("Plain", .receipts), favorite("Also", order: 1, .wallet)]
    ).grid
    #expect(grid.title == "Favorites")
    #expect(Set(grid.tiles.map(\.title)) == ["Kept", "Also"])
    #expect(grid.tiles.allSatisfy { $0.dot != nil })
}

@Test func favoritesFollowFavoriteOrder() {
    let grid = GridHarness(
        .favorites,
        [
            favorite("Third", order: 2), favorite("First", order: 0, daysAgo: 9), favorite("Second", order: 1),
        ]
    ).grid
    #expect(grid.tiles.map(\.title) == ["First", "Second", "Third"])
}

@Test func tiedFavoritesBothShow() {
    let grid = GridHarness(
        .favorites, [favorite("Older", order: 4, daysAgo: 3), favorite("Newer", order: 4)]
    ).grid
    #expect(grid.tiles.map(\.title) == ["Newer", "Older"])
}

@Test func trashedFavoritesLeaveFavorites() {
    var gone = favorite("In Trash", order: 0)
    gone.trashedDay = CalendarDay(year: 2026, month: 10, day: 10)
    let grid = GridHarness(.favorites, [gone, favorite("Here", order: 1)]).grid
    #expect(grid.tiles.map(\.title) == ["Here"])
}

@Test func favoritesSubtitleIsTheCount() {
    let scans = (0..<10).map { favorite("Scan \($0)", order: $0) }
    #expect(GridHarness(.favorites, scans).grid.subtitle == "10 scans")
    let empty = GridHarness(.favorites, []).grid
    #expect(empty.isEmpty)
    #expect(empty.emptyTitle == "No favorites yet")
    #expect(empty.emptyBody == "Tap the heart on a scan to keep it one tap from Home.")
}

@Test func tilesCarryTheirHeart() {
    let grid = GridHarness(.all, [favorite("Kept", order: 0), scan("Plain", .receipts, daysAgo: 1)]).grid
    #expect(grid.tiles.map(\.isFavorite) == [true, false])
}

@Test func tileLabelSaysFavorite() {
    let grid = GridHarness(.all, [favorite("Corner Market", order: 0), scan("Harbor Gas", .receipts, daysAgo: 1)]).grid
    #expect(grid.tiles[0].accessibilityLabel == "Corner Market, Receipts, Oct 12 · 3 mo left, favorite")
    #expect(grid.tiles[1].accessibilityLabel == "Harbor Gas, Receipts, \(grid.tiles[1].detail)")
}

@Test func toggleFavoriteFromATile() {
    let harness = GridHarness(.all, [scan("Corner Market", .receipts)])
    let id = harness.grid.tiles[0].id
    harness.grid.toggleFavorite(id)
    #expect(harness.grid.tiles[0].isFavorite)
    #expect(harness.analytics.events == [.favoritesChanged(isFavorite: true, count: 1)])
    harness.grid.toggleFavorite(id)
    #expect(!harness.grid.tiles[0].isFavorite)
    #expect(harness.analytics.events.last == .favoritesChanged(isFavorite: false, count: 1))
}

@Test func failedToggleShowsTheAlert() {
    let harness = GridHarness(.all, [scan("Corner Market", .receipts)])
    harness.library.failNextEdit = .writeFailed
    harness.grid.toggleFavorite(harness.grid.tiles[0].id)
    #expect(harness.grid.editAlert == EditAlert())
    #expect(!harness.grid.tiles[0].isFavorite)
    #expect(harness.analytics.events.isEmpty)
}
