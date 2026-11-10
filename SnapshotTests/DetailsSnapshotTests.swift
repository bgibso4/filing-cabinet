import Core
import Library
import ScreenModels
import Screens
import SwiftUI
import TestSupport
import XCTest

/// Details over the viewer (ScanDetails.dc.html): the lease (07-01), the receipt (07-02, 07-08 dark, 12-04 largest
/// text), after a move (07-05) and renaming (07-03, without the keyboard). Menus and alerts are not snapshotted; the
/// journey attaches screenshots of them.
final class DetailsSnapshotTests: XCTestCase {
    /// The viewer with Details fully up, as `ViewerRoute` lays them out. Both live in the pushed destination, so the
    /// panel's measured height reaches the viewer (a destination's content isn't evaluated again for its parent's state).
    private struct DetailsOverViewer: View {
        let viewer: ViewerModel
        let details: DetailsModel

        @State private var height: CGFloat = 0

        var body: some View {
            ViewerView(
                model: viewer,
                pages: Fixtures.pages,
                thumbnails: Fixtures.thumbnails,
                detailsHeight: height,
                detailsProgress: 1
            )
            .overlay(alignment: .bottom) {
                DetailsPanel(model: details, progress: 1, height: $height)
            }
        }
    }

    /// Pushed on a navigation stack, because the back button is the system's and only a pushed screen has one.
    private struct DetailsScreen: View {
        let content: DetailsOverViewer

        var body: some View {
            NavigationStack(path: .constant([0])) {
                Color.clear.navigationDestination(for: Int.self) { _ in content }
            }
        }
    }

    @MainActor
    private func screen(_ scan: ScanSummary, change: (DetailsModel) -> Void = { _ in }) -> DetailsScreen {
        let library = FakeLibrary(scans: [scan])
        let today = Today(clock: Fixtures.clock)
        let viewer = ViewerModel(
            id: scan.id,
            library: library,
            today: today,
            calendar: Fixtures.clock.calendar,
            analytics: RecordingAnalytics(),
            history: Fixtures.searchHistory())
        let details = DetailsModel(
            id: scan.id, library: library, today: today, clock: Fixtures.clock, analytics: RecordingAnalytics())
        change(details)
        return DetailsScreen(content: DetailsOverViewer(viewer: viewer, details: details))
    }

    /// One variant at a time, each with new models: closing a window ends renaming (the sheet commits the title as it
    /// disappears), so a screen shared across variants would leave the later ones out of the state under test.
    @MainActor
    private func assertScreens(
        _ scan: ScanSummary, testName: String, change: @escaping (DetailsModel) -> Void = { _ in }
    ) throws {
        for variant in SnapshotConfig.variants {
            try SnapshotHost.assertScreen(screen(scan, change: change), testName: testName, variants: [variant])
        }
    }

    @MainActor
    func testLease() throws {
        try assertScreens(Fixtures.lease, testName: "details_lease")
    }

    /// Oct 16, not the mock's Oct 17 (A10).
    @MainActor
    func testReceipt() throws {
        try assertScreens(Fixtures.receipt, testName: "details_receipt")
    }

    @MainActor
    func testMoved() throws {
        try assertScreens(Fixtures.receipt, testName: "details_moved") { $0.choose(.documents) }
    }

    @MainActor
    func testRename() throws {
        try assertScreens(Fixtures.lease, testName: "details_rename") { $0.startRenaming() }
    }
}
