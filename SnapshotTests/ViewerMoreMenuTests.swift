import Core
import Library
import ScreenModels
import Screens
import SwiftUI
import TestSupport
import Testing
import UIKit

/// More's menu in a real window (06-03, M11): Copy Text comes on once reading finishes while the viewer is open.
@MainActor
struct ViewerMoreMenuTests {
    @Test func copyTextComesOnWhenReadingFinishes() async throws {
        let scan = ScanSummary(
            id: ScanID(),
            title: "Lease 2026",
            collection: .documents,
            scannedAt: Fixtures.clock.now(),
            expiryOverride: nil,
            pageCount: 1)
        let library = FakeLibrary(scans: [scan])
        let model = ViewerModel(
            id: scan.id,
            library: library,
            today: Today(clock: Fixtures.clock),
            calendar: Fixtures.clock.calendar,
            analytics: RecordingAnalytics(),
            history: Fixtures.searchHistory(),
            export: Fixtures.export,
            photos: Fixtures.photos)
        let window = try host(
            NavigationStack(path: .constant([0])) {
                Color.clear.navigationDestination(for: Int.self) { _ in
                    ViewerView(model: model, pages: Fixtures.pages, thumbnails: Fixtures.thumbnails)
                }
            })
        defer {
            window.rootViewController = nil
            window.isHidden = true
        }
        #expect(try await eventually { copyText(in: window)?.attributes.contains(.disabled) == true })

        library.updateSearchText("Harlow Property", for: scan.id)

        #expect(try await eventually { copyText(in: window)?.attributes.contains(.disabled) == false })
    }

    /// The Copy Text item of the More button's menu, as the menu would open now.
    private func copyText(in window: UIWindow) -> UIAction? {
        // The More button is the only one whose tap opens a menu (`MenuButton`). A plain loop: a lazy `compactMap`'s
        // `first` calls its closure twice for the match, which doubles the walk at every level.
        func more(in view: UIView) -> UIButton? {
            if let button = view as? UIButton, button.showsMenuAsPrimaryAction { return button }
            for subview in view.subviews {
                if let button = more(in: subview) { return button }
            }
            return nil
        }
        return more(in: window)?.menu?.children.compactMap { $0 as? UIAction }.first { $0.title == "Copy Text" }
    }

    private func host(_ view: some View) throws -> UIWindow {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        window.rootViewController = UIHostingController(rootView: view)
        window.makeKeyAndVisible()
        return window
    }

    /// Polls for up to 5 s until `condition` holds; false if it never did.
    private func eventually(_ condition: () -> Bool) async throws -> Bool {
        let end = ContinuousClock.now + .seconds(5)
        while ContinuousClock.now < end {
            if condition() { return true }
            try await Task.sleep(for: .milliseconds(100))
        }
        return false
    }
}
