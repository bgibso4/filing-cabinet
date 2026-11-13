import Core
import Foundation
import Library
import ScreenModels
import Screens
import SwiftUI
import TestSupport
import XCTest

/// Settings (Settings2.dc.html): the list with Apple Intelligence and notifications on (10-01, 10-07 dark, 12-05 large
/// text), both off on an iPhone without Apple Intelligence and with notifications blocked in iPhone Settings (10-06),
/// and older scans being read (Plan 5's demo); Collections (10-02) and Receipts' screen (10-03). Titles rest small in
/// the bar (plan 3). Send feedback comes with a later plan. The menu and the shortening confirmation are not
/// snapshotted; the journey attaches screenshots of them.
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

    /// `library` holds the scans the pass reads; with the default suggester it reads nothing.
    @MainActor
    private func settings(
        _ authorization: NotificationAuthorization,
        suggester: FakeScanSuggester = FakeScanSuggester(filing: .fails),
        library: FakeLibrary = FakeLibrary()
    ) async throws -> some View {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let preferences = AppPreferences(defaults: defaults)
        let pass = SearchWordsPass(
            library: library,
            today: Today(clock: Fixtures.clock),
            suggester: suggester,
            preferences: preferences,
            isBusy: { false })
        addTeardownBlock { @MainActor in pass.pause() }
        let model = SettingsModel(
            preferences: preferences,
            notifications: FakeNotificationCenter(authorization: authorization),
            suggester: suggester,
            wordsPass: pass,
            version: "1.0")
        // What the screen reads as it appears, read here first so the first frame already shows it.
        await model.refreshAuthorization()
        pass.resume()
        // The pass sets its progress as it starts on the first scan, before it waits for the model.
        try await Task.sleep(for: .milliseconds(100))
        return Pushed(content: SettingsView(model: model, onOpenCollections: {}))
    }

    @MainActor
    func testSettings() async throws {
        try SnapshotHost.assertScreen(try await settings(.authorized), testName: "settings")
    }

    /// 10-06: no Apple Intelligence on this iPhone, and notifications blocked in iPhone Settings.
    @MainActor
    func testSettingsWithNotificationsBlocked() async throws {
        try SnapshotHost.assertScreen(
            try await settings(.denied, suggester: FakeScanSuggester.unavailable()), testName: "settings_blocked")
    }

    /// Plan 5's demo: 12 of 91 scans read, the model still answering about the 13th.
    @MainActor
    func testSettingsReadingOlderScans() async throws {
        let scans = (0..<91).map { index in
            ScanSummary(
                id: ScanID(),
                title: "Letter \(index)",
                collection: .documents,
                scannedAt: Fixtures.clock.now().addingTimeInterval(-Double(index) * 86_400),
                expiryOverride: nil,
                pageCount: 1)
        }
        let library = FakeLibrary(scans: scans)
        // The oldest twelve already have words; any version counts, as seeding's does.
        for scan in scans.suffix(12) { library.updateSearchWords(["letter"], version: .max, for: scan.id) }
        let suggester = FakeScanSuggester(filing: .fails, words: .never)
        try SnapshotHost.assertScreen(
            try await settings(.authorized, suggester: suggester, library: library), testName: "settings_reading")
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

    /// The state a pull reaches: the large title over its subtitle, the bar's centre empty.
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
