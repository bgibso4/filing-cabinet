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
    /// The system draws a presented sheet's chrome, which a snapshot can't capture, so this reproduces it over the
    /// viewer: the compact sheet's rounded surface 8 pt in from the screen's sides and bottom (ScanDetails.dc.html
    /// line 34). The sheet draws its own grabber. Both live in the pushed destination, so the sheet's measured height
    /// reaches the viewer (a destination's content isn't evaluated again for its parent's state).
    private struct DetailsOverViewer: View {
        private static let inset: CGFloat = 8
        private static let cornerRadius: CGFloat = 34

        let viewer: ViewerModel
        let details: DetailsModel
        /// Screens' resource bundle, where the token colours live.
        let screensBundle: Bundle

        @State private var height: CGFloat = 0

        var body: some View {
            ViewerView(model: viewer, pages: Fixtures.pages, thumbnails: Fixtures.thumbnails, detailsHeight: height)
                .overlay(alignment: .bottom) {
                    DetailsSheet(model: details, height: $height)
                        .background(Color("bg-surface", bundle: screensBundle))
                        .clipShape(.rect(cornerRadius: Self.cornerRadius))
                        .padding([.horizontal, .bottom], Self.inset)
                        .ignoresSafeArea(edges: .bottom)
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
    private func screen(_ scan: ScanSummary, change: (DetailsModel) -> Void = { _ in }) throws -> DetailsScreen {
        let library = FakeLibrary(scans: [scan])
        let today = Today(clock: Fixtures.clock)
        let viewer = ViewerModel(id: scan.id, library: library, today: today, calendar: Fixtures.clock.calendar)
        let details = DetailsModel(
            id: scan.id, library: library, today: today, clock: Fixtures.clock, analytics: RecordingAnalytics())
        change(details)
        // Screens' resources are a bundle inside the host app.
        let url = Bundle.main.url(forResource: "FilingCabinetKit_Screens", withExtension: "bundle")
        let bundle = try XCTUnwrap(url.flatMap(Bundle.init(url:)))
        return DetailsScreen(content: DetailsOverViewer(viewer: viewer, details: details, screensBundle: bundle))
    }

    @MainActor
    func testLease() throws {
        try SnapshotHost.assertScreen(screen(Fixtures.lease), testName: "details_lease")
    }

    /// Oct 16, not the mock's Oct 17 (A10).
    @MainActor
    func testReceipt() throws {
        try SnapshotHost.assertScreen(screen(Fixtures.receipt), testName: "details_receipt")
    }

    @MainActor
    func testMoved() throws {
        try SnapshotHost.assertScreen(screen(Fixtures.receipt) { $0.choose(.documents) }, testName: "details_moved")
    }

    @MainActor
    func testRename() throws {
        try SnapshotHost.assertScreen(screen(Fixtures.lease) { $0.startRenaming() }, testName: "details_rename")
    }
}
