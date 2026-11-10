import Core
import ScreenModels
import Screens
import SwiftUI
import TestSupport
import XCTest

/// Trash (Trash.dc.html, option D): the grid (09-01, 09-10 dark), selecting two (09-02, 09-11 dark) and empty (09-09).
/// The long-press menu and the confirmations are not snapshotted; the journey attaches screenshots of them.
final class TrashSnapshotTests: XCTestCase {
    /// Pushed on a navigation stack, because the back button and Select are in the system's bar.
    private struct TrashScreen: View {
        let model: TrashModel

        var body: some View {
            NavigationStack(path: .constant([0])) {
                Color.clear.navigationDestination(for: Int.self) { _ in
                    TrashView(model: model, thumbnails: Fixtures.thumbnails, onOpen: { _ in })
                }
            }
        }
    }

    @MainActor
    private func screen(_ library: FakeLibrary, change: (TrashModel) -> Void) -> TrashScreen {
        let model = TrashModel(
            library: library,
            today: Today(clock: Fixtures.clock),
            calendar: Fixtures.clock.calendar,
            analytics: RecordingAnalytics())
        change(model)
        return TrashScreen(model: model)
    }

    /// One variant at a time, each with a new model, as the Details snapshots do, so no variant inherits another's state.
    @MainActor
    private func assertScreens(
        _ library: @autoclosure () -> FakeLibrary, testName: String, change: (TrashModel) -> Void = { _ in }
    ) throws {
        for variant in SnapshotConfig.variants {
            try SnapshotHost.assertScreen(
                screen(library(), change: change), testName: testName, variants: [variant])
        }
    }

    @MainActor
    func testList() throws {
        // Two favourites keep their hearts in Trash (05-07's mark, M13).
        let library = Fixtures.library(.trash)
        try library.setFavorite(true, for: library.scans.prefix(2).map(\.id))
        try assertScreens(library, testName: "trash_list")
    }

    /// Ten scans: the last row rests under Empty Trash's glass and scrolls clear of it (Ben, 2026-11-08; no fade since
    /// 2026-11-10). Light and dark; trash_list covers the largest text.
    @MainActor
    func testUnderTheBar() throws {
        for variant in SnapshotConfig.variants where !variant.size.isAccessibilitySize {
            try SnapshotHost.assertScreen(
                screen(Fixtures.library(.fullTrash)) { _ in }, testName: "trash_under_bar", variants: [variant])
        }
    }

    /// Parking stub and Coat check ticked, as in the mock.
    @MainActor
    func testSelect() throws {
        let library = Fixtures.library(.trash)
        try assertScreens(library, testName: "trash_select") { model in
            model.toggleSelecting()
            library.scans.prefix(2).forEach { model.toggle($0.id) }
        }
    }

    @MainActor
    func testEmpty() throws {
        try assertScreens(FakeLibrary(), testName: "trash_empty")
    }
}
