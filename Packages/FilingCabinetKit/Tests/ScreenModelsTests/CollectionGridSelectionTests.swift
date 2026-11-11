import Core
import Foundation
import Library
import Testing

@testable import ScreenModels
@testable import TestSupport

// A grid's selection shared and favourited (Plan 4 Task 12, B12): the bar's Share, Favorite and Move to Trash.

private func favorite(_ title: String, order: Int, daysAgo: Int = 0) -> ScanSummary {
    var made = scan(title, .receipts, daysAgo: daysAgo)
    made.favoriteOrder = order
    return made
}

@Test func favoriteLabelFollowsTheSelection() {
    let harness = GridHarness(
        .collection(.receipts),
        [favorite("Kept", order: 0), scan("Plain", .receipts, daysAgo: 1), favorite("Also", order: 1, daysAgo: 2)])
    let grid = harness.grid
    grid.toggleSelecting()
    #expect(grid.favoriteTitle == "Favorite")
    #expect(!grid.selectionIsFavorite)
    grid.toggle(grid.tiles[0].id)
    #expect(grid.favoriteTitle == "Remove from Favorites")
    #expect(grid.selectionIsFavorite)
    grid.toggle(grid.tiles[1].id)
    #expect(grid.favoriteTitle == "Favorite", "one of them isn't a favourite")
    #expect(!grid.selectionIsFavorite)
    grid.toggle(grid.tiles[1].id)
    grid.toggle(grid.tiles[2].id)
    #expect(grid.favoriteTitle == "Remove from Favorites")
}

/// New favourites go last in the order the grid shows them, and favouriting ends select mode (#68's actions do).
@Test func favoritingSeveralKeepsScreenOrder() {
    let harness = GridHarness(
        .all,
        [
            scan("Third", .receipts, daysAgo: 2), favorite("Already", order: 0, daysAgo: 3), scan("First", .wallet),
            scan("Second", .notes, daysAgo: 1),
        ])
    let grid = harness.grid
    grid.toggleSelecting()
    // Ticked out of screen order, and one already a favourite.
    for title in ["Third", "First", "Already", "Second"] {
        grid.toggle(grid.tiles.first { $0.title == title }?.id ?? ScanID())
    }
    grid.favoriteSelected()
    #expect(!grid.isSelecting)
    let favorites = harness.library.scans.filter(\.isFavorite).sorted(by: ScanSummary.favoritesOrder)
    #expect(favorites.map(\.title) == ["Already", "First", "Second", "Third"])
    #expect(harness.analytics.events == [.favoritesChanged(isFavorite: true, count: 4)])
}

@Test func removingTheSelectionFromFavorites() {
    let harness = GridHarness(
        .collection(.receipts), [favorite("Kept", order: 0), favorite("Also", order: 1, daysAgo: 1)])
    let grid = harness.grid
    grid.toggleSelecting()
    grid.tiles.forEach { grid.toggle($0.id) }
    grid.favoriteSelected()
    #expect(!grid.isSelecting)
    #expect(grid.tiles.allSatisfy { !$0.isFavorite })
    #expect(harness.analytics.events == [.favoritesChanged(isFavorite: false, count: 2)])
}

@Test func aFailedFavoriteAlertsAndKeepsTheSelection() {
    let harness = GridHarness(.collection(.receipts), [scan("Plain", .receipts)])
    let grid = harness.grid
    grid.toggleSelecting()
    grid.toggle(grid.tiles[0].id)
    harness.library.failNextEdit = .writeFailed
    grid.favoriteSelected()
    #expect(grid.editAlert == EditAlert())
    #expect(grid.isSelecting)
    #expect(grid.selected.count == 1)
    #expect(!grid.tiles[0].isFavorite)
    #expect(harness.analytics.events.isEmpty)
}

/// B12: where "Move 387 to Trash" doesn't fit, the pill says "Move to Trash"; the count is in the subtitle.
@Test func thePillsShortTitleDropsTheCount() {
    let harness = GridHarness(.collection(.receipts), (0..<387).map { scan("Receipt \($0)", .receipts) })
    let grid = harness.grid
    grid.toggleSelecting()
    grid.tiles.forEach { grid.toggle($0.id) }
    #expect(grid.moveTitle == "Move 387 to Trash")
    #expect(grid.shortMoveTitle == "Move to Trash")
    #expect(grid.subtitle == "387 selected")
}

/// M10: one PDF per scan, in screen order, a repeated title numbered; the share is reported once, with the count.
@Test func sharingTheSelectionSendsAPDFPerScan() async throws {
    let folder = ExportFolder()
    let scans = [
        scan("Receipt", .receipts), scan("Rent/Oct", .receipts, daysAgo: 1), scan("Receipt", .receipts, daysAgo: 2),
        scan("Not shared", .receipts, daysAgo: 3),
    ]
    for scan in scans { _ = try await folder.files.write([SyntheticPages.blank()], for: scan.id) }
    let harness = GridHarness(.collection(.receipts), scans, export: folder.export)
    let grid = harness.grid
    grid.toggleSelecting()
    grid.tiles.prefix(3).reversed().forEach { grid.toggle($0.id) }
    let pdfs = grid.sharedPDFs
    #expect(pdfs.map(\.suggestedFileName) == ["Receipt", "Rent-Oct", "Receipt 2"])
    #expect(harness.analytics.events.isEmpty, "nothing is reported until the share sheet makes the files")
    for pdf in pdfs { _ = try await pdf.file() }
    #expect(harness.analytics.events == [.scansExported(kind: .share, count: 3)])
}

/// M20: the shared PDFs go when select mode ends (and when the grid goes, `exportEnded`).
@Test func endingSelectModeRemovesTheSharedFiles() async throws {
    let folder = ExportFolder()
    let shared = scan("Receipt", .receipts)
    _ = try await folder.files.write([SyntheticPages.blank()], for: shared.id)
    let harness = GridHarness(.collection(.receipts), [shared], export: folder.export)
    let grid = harness.grid
    grid.toggleSelecting()
    grid.toggle(grid.tiles[0].id)
    let pdf = try await #require(grid.sharedPDFs.first).file()
    #expect(FileManager.default.fileExists(atPath: pdf.path(percentEncoded: false)))
    grid.toggleSelecting()
    #expect(!FileManager.default.fileExists(atPath: pdf.path(percentEncoded: false)))

    grid.toggleSelecting()
    grid.toggle(grid.tiles[0].id)
    let again = try await #require(grid.sharedPDFs.first).file()
    grid.exportEnded()
    #expect(!FileManager.default.fileExists(atPath: again.path(percentEncoded: false)))
}

@Test func nothingSelectedSharesNothing() {
    let grid = GridHarness(.collection(.receipts), [scan("Receipt", .receipts)]).grid
    grid.toggleSelecting()
    #expect(grid.sharedPDFs.isEmpty)
}
