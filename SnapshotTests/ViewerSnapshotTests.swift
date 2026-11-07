import Library
import ScreenModels
import Screens
import SwiftUI
import TestSupport
import XCTest

final class ViewerSnapshotTests: XCTestCase {
    @MainActor
    private func viewer(_ scan: ScanSummary) -> some View {
        let model = ViewerModel(
            id: scan.id,
            library: FakeLibrary(scans: [scan]),
            today: Today(clock: Fixtures.clock),
            calendar: Fixtures.clock.calendar)
        // Pushed on a navigation stack, because the back button is the system's and only a pushed screen has one.
        return NavigationStack(path: .constant([0])) {
            Color.clear.navigationDestination(for: Int.self) { _ in
                ViewerView(model: model, pages: Fixtures.pages, thumbnails: Fixtures.thumbnails)
            }
        }
    }

    @MainActor
    func testLease() throws {
        try SnapshotHost.assertScreen(viewer(Fixtures.lease), testName: "viewer_lease")
    }

    @MainActor
    func testReceipt() throws {
        try SnapshotHost.assertScreen(viewer(Fixtures.receipt), testName: "viewer_receipt")
    }
}
