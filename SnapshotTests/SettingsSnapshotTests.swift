import Core
import Foundation
import ScreenModels
import Screens
import SwiftUI
import TestSupport
import XCTest

/// Settings (Settings2.dc.html): the list with notifications on (10-01, 10-07 dark, 12-05 large text) and blocked in
/// iPhone Settings (10-06), Collections (10-02) and Receipts' screen (10-03). Titles rest small in the bar (plan 3).
/// The Apple Intelligence and Send feedback rows come with later plans. The menu and the shortening confirmation are
/// not snapshotted; the journey attaches screenshots of them.
final class SettingsSnapshotTests: XCTestCase {
    /// Pushed on a navigation stack, because the back button is in the system's bar.
    private struct Pushed<Content: View>: View {
        let content: Content

        var body: some View {
            NavigationStack(path: .constant([0])) {
                Color.clear.navigationDestination(for: Int.self) { _ in content }
            }
        }
    }

    /// A suite no other test reads, emptied before and after, so no preference leaks in or out.
    private let suite = "SettingsSnapshotTests"

    override func tearDown() {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    @MainActor
    private func settings(_ authorization: NotificationAuthorization) async throws -> some View {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let model = SettingsModel(
            preferences: AppPreferences(defaults: defaults),
            notifications: FakeNotificationCenter(authorization: authorization),
            version: "1.0")
        // What the screen reads as it appears, read here first so the first frame already shows it.
        await model.refreshAuthorization()
        return Pushed(content: SettingsView(model: model, onOpenCollections: {}))
    }

    @MainActor
    func testSettings() async throws {
        try SnapshotHost.assertScreen(try await settings(.authorized), testName: "settings")
    }

    @MainActor
    func testSettingsWithNotificationsBlocked() async throws {
        try SnapshotHost.assertScreen(try await settings(.denied), testName: "settings_blocked")
    }

    @MainActor
    private func collections(rest: HeaderRest) -> some View {
        let model = CollectionsModel(
            library: Fixtures.library(.home), today: Today(clock: Fixtures.clock), calendar: Fixtures.clock.calendar)
        return Pushed(content: CollectionsView(model: model, rest: rest, onOpen: { _ in }))
    }

    /// Short content, resting small in the bar like a long screen (plan 3, M8).
    @MainActor
    func testCollections() throws {
        try SnapshotHost.assertScreen(collections(rest: .small), testName: "collections")
    }

    /// The state a pull reaches: the large title over its subtitle, the bar's centre empty. The snapshot cuts the top
    /// few points off the large title at the default text size; the app doesn't (a pulled or resting-large screen
    /// shows it whole), and a real push in the host doesn't change the snapshot, so it is the snapshot's rendering of
    /// the bar.
    @MainActor
    func testCollectionsLarge() throws {
        try SnapshotHost.assertScreen(collections(rest: .large), testName: "collections_large")
    }

    @MainActor
    func testReceipts() throws {
        let model = CollectionSettingsModel(
            collection: .receipts,
            library: Fixtures.library(.home),
            today: Today(clock: Fixtures.clock),
            calendar: Fixtures.clock.calendar,
            analytics: RecordingAnalytics())
        try SnapshotHost.assertScreen(
            Pushed(content: CollectionSettingsView(model: model)), testName: "collection_receipts")
    }
}
