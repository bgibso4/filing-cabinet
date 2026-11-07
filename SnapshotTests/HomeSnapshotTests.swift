import Library
import ScreenModels
import Screens
import TestSupport
import XCTest

final class HomeSnapshotTests: XCTestCase {
    @MainActor
    private func home(_ library: FakeLibrary) -> HomeView {
        let model = HomeModel(library: library, today: Today(clock: Fixtures.clock), calendar: Fixtures.clock.calendar)
        return HomeView(model: model, canScan: true, onScan: {}, onOpen: { _ in })
    }

    @MainActor
    func testHomeFirstLaunch() throws {
        try SnapshotHost.assertScreen(home(FakeLibrary()), testName: "home_first")
    }

    @MainActor
    func testHomeWithScans() throws {
        try SnapshotHost.assertScreen(home(Fixtures.library(.home)), testName: "home_scans")
    }
}
