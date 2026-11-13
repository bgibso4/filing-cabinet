import Foundation
import ScreenModels
import Screens
import SwiftUI
import TestSupport
import XCTest

/// The first-launch welcome (01-03, 01-07) and "Know when it cleans up" (01-04, 01-08), light, dark and at the largest
/// text.
final class WelcomeSnapshotTests: XCTestCase {
    /// The system draws a presented sheet's chrome, which a snapshot can't capture, so this reproduces it: the large
    /// sheet's surface from under the status bar to the bottom of the screen, with rounded top corners (Home.dc.html
    /// line 213). The dimmed Home behind it is left out.
    private struct SheetChrome: View {
        private static let cornerRadius: CGFloat = 14

        let model: WelcomeModel
        /// Screens' resource bundle, where the token colours live.
        let screensBundle: Bundle

        var body: some View {
            // The surface reaches the bottom edge; the content keeps clear of the home indicator, as in a real sheet.
            WelcomeSheet(model: model)
                .background {
                    UnevenRoundedRectangle(topLeadingRadius: Self.cornerRadius, topTrailingRadius: Self.cornerRadius)
                        .fill(Color("bg-surface", bundle: screensBundle))
                        .ignoresSafeArea(edges: .bottom)
                }
                .background(Color("bg-grouped", bundle: screensBundle))
        }
    }

    private let suite = "WelcomeSnapshotTests"

    override func tearDown() {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    @MainActor
    func testWelcome() async throws {
        let model = try makeModel()
        await model.start()
        try SnapshotHost.assertScreen(try chrome(model), testName: "welcome")
    }

    @MainActor
    func testNotifications() async throws {
        let model = try makeModel()
        await model.start()
        await model.continueTapped()
        XCTAssertEqual(model.step, .notifications)
        try SnapshotHost.assertScreen(try chrome(model), testName: "notifications")
    }

    /// A welcome on a fresh install, where iOS hasn't asked about notifications yet.
    @MainActor
    private func makeModel() throws -> WelcomeModel {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return WelcomeModel(
            preferences: AppPreferences(defaults: defaults),
            notifications: FakeNotificationCenter(authorization: .notDetermined),
            analytics: RecordingAnalytics())
    }

    @MainActor
    private func chrome(_ model: WelcomeModel) throws -> SheetChrome {
        // Screens' resources are a bundle inside the host app.
        let url = Bundle.main.url(forResource: "FilingCabinetKit_Screens", withExtension: "bundle")
        return SheetChrome(model: model, screensBundle: try XCTUnwrap(url.flatMap(Bundle.init(url:))))
    }
}
