import Core
import ScreenModels
import Screens
import SwiftUI
import TestSupport
import XCTest

final class GridSnapshotTests: XCTestCase {
    @MainActor
    private func grid(_ kind: GridKind, _ library: FakeLibrary) -> some View {
        let model = CollectionGridModel(
            kind: kind, library: library, today: Today(clock: Fixtures.clock), calendar: Fixtures.clock.calendar)
        // Pushed on a navigation stack, because the back button is the system's and only a pushed screen has one.
        return NavigationStack(path: .constant([0])) {
            Color.clear.navigationDestination(for: Int.self) { _ in
                CollectionGridView(
                    model: model, thumbnails: Fixtures.thumbnails, canScan: true, onOpen: { _ in }, onScan: {})
            }
        }
    }

    @MainActor
    func testReceipts() throws {
        try SnapshotHost.assertScreen(grid(.collection(.receipts), Fixtures.library(.home)), testName: "grid_receipts")
    }

    @MainActor
    func testWallet() throws {
        try SnapshotHost.assertScreen(grid(.collection(.wallet), Fixtures.library(.home)), testName: "grid_wallet")
    }

    @MainActor
    func testThrowaways() throws {
        try SnapshotHost.assertScreen(
            grid(.collection(.throwaways), Fixtures.library(.home)), testName: "grid_throwaways")
    }

    @MainActor
    func testRecent() throws {
        try SnapshotHost.assertScreen(grid(.recent, Fixtures.library(.home)), testName: "grid_recent")
    }

    @MainActor
    func testAll() throws {
        try SnapshotHost.assertScreen(grid(.all, Fixtures.library(.home)), testName: "grid_all")
    }

    @MainActor
    func testEmpty() throws {
        try SnapshotHost.assertScreen(grid(.collection(.receipts), FakeLibrary()), testName: "grid_empty")
    }
}
