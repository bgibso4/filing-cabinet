import Core
import Foundation
import Library
import ScreenModels
import Screens
import SwiftUI
import TestSupport
import XCTest

final class HomeSnapshotTests: XCTestCase {
    /// At the root of a navigation stack, as in the app, because the title and the gear are in the system's bar.
    @MainActor
    private func home(_ library: FakeLibrary) -> some View {
        let model = HomeModel(library: library, today: Today(clock: Fixtures.clock), calendar: Fixtures.clock.calendar)
        return rooted(HomeView(model: model, canScan: true, onScan: {}, onOpen: { _ in }))
    }

    @MainActor
    private func rooted(_ home: HomeView) -> some View {
        NavigationStack { home }
    }

    @MainActor
    func testHomeFirstLaunch() throws {
        try SnapshotHost.assertScreen(home(FakeLibrary()), testName: "home_first")
    }

    @MainActor
    func testHomeWithScans() throws {
        try SnapshotHost.assertScreen(home(Fixtures.library(.home)), testName: "home_scans")
    }

    /// 02-04 and 02-07 without Search and Favorites (later plans): notes are blocked, so four Throwaways that went to
    /// Trash on their own since Home was last seen make the banner.
    @MainActor
    func testHomeAfterACleanup() async throws {
        let suite = "HomeSnapshotTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = AppPreferences(defaults: defaults)
        preferences.cleanupSeenThrough = Fixtures.clock.today.adding(days: -14, in: Fixtures.clock.calendar)
        let library = Fixtures.library(.afterCleanup)
        let today = Today(clock: Fixtures.clock)
        let banner = CleanupBanner(
            library: library,
            today: today,
            preferences: preferences,
            notifications: FakeNotificationCenter(authorization: .denied))
        await banner.refreshAuthorization()
        let model = HomeModel(library: library, today: today, calendar: Fixtures.clock.calendar, banner: banner)
        try SnapshotHost.assertScreen(
            rooted(HomeView(model: model, canScan: true, onScan: {}, onOpen: { _ in })), testName: "home_banner")
    }
}
