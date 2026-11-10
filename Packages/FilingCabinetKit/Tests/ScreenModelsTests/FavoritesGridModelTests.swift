import Core
import Foundation
import Library
import Testing

@testable import ScreenModels
@testable import TestSupport

// The Favorites grid while it is on screen (M9, Review Focus 6).

private func favorites(_ titles: String...) -> [ScanSummary] {
    titles.enumerated().map { index, title in
        var made = scan(title, .wallet, daysAgo: index)
        made.favoriteOrder = index
        return made
    }
}

@Test func unfavoritedTileStaysUntilLeaving() {
    let harness = GridHarness(.favorites, favorites("License", "Lease", "Passport"))
    let lease = harness.grid.tiles[1].id

    harness.grid.toggleFavorite(lease)

    // Still in its place, with an empty heart.
    #expect(harness.grid.tiles.map(\.title) == ["License", "Lease", "Passport"])
    #expect(harness.grid.tiles.map(\.isFavorite) == [true, false, true])
    #expect(harness.grid.tiles.map(\.isUnfavorited) == [false, true, false])
    #expect(harness.grid.tiles[1].accessibilityLabel == "Lease, Wallet, Kept forever, not a favorite")
    #expect(harness.analytics.events == [.favoritesChanged(isFavorite: false, count: 1)])

    // Leaving and coming back builds the screen's model again: the tile is gone.
    #expect(harness.reopened().tiles.map(\.title) == ["License", "Passport"])
}

/// Un-favourited elsewhere (the viewer pushed from the grid), the tile stays too.
@Test func unfavoritedInTheLibraryStaysToo() throws {
    let harness = GridHarness(.favorites, favorites("License", "Lease"))
    #expect(harness.grid.tiles.count == 2)
    try harness.library.setFavorite(false, for: [harness.grid.tiles[0].id])
    #expect(harness.grid.tiles.map(\.title) == ["License", "Lease"])
    #expect(harness.grid.tiles.map(\.isUnfavorited) == [true, false])
}

@Test func subtitleCountIsLive() {
    let harness = GridHarness(.favorites, favorites("License", "Lease", "Passport"))
    #expect(harness.grid.subtitle == "3 scans")
    harness.grid.toggleFavorite(harness.grid.tiles[0].id)
    #expect(harness.grid.subtitle == "2 scans")
    harness.grid.toggleFavorite(harness.grid.tiles[1].id)
    harness.grid.toggleFavorite(harness.grid.tiles[2].id)
    #expect(harness.grid.subtitle == "No scans")
    #expect(!harness.grid.isEmpty, "the kept tiles still show")
}

/// Task 3 review L1: a kept tile isn't a favourite any more, but its heart still works.
@Test func refavoritingAKeptTileWorks() {
    let harness = GridHarness(.favorites, favorites("License", "Lease", "Passport"))
    let lease = harness.grid.tiles[1].id
    harness.grid.toggleFavorite(lease)

    harness.grid.toggleFavorite(lease)

    #expect(harness.grid.tiles.map(\.title) == ["License", "Lease", "Passport"])
    #expect(harness.grid.tiles.map(\.isFavorite) == [true, true, true])
    #expect(harness.grid.tiles.map(\.isUnfavorited) == [false, false, false])
    #expect(harness.grid.subtitle == "3 scans")
    #expect(harness.analytics.events.last == .favoritesChanged(isFavorite: true, count: 1))
}

/// A kept tile that goes to Trash leaves, as any tile does.
@Test func keptTileLeavesForTrash() throws {
    let harness = GridHarness(.favorites, favorites("License", "Lease"))
    let lease = harness.grid.tiles[1].id
    harness.grid.toggleFavorite(lease)
    try harness.library.moveToTrash([lease])
    #expect(harness.grid.tiles.map(\.title) == ["License"])
}

/// Only Favorites keeps them: another grid drops a heart in place and keeps the tile anyway.
@Test func otherGridsKeepNothing() {
    let harness = GridHarness(.all, favorites("License"))
    harness.grid.toggleFavorite(harness.grid.tiles[0].id)
    #expect(harness.grid.tiles.map(\.isUnfavorited) == [false])
}
