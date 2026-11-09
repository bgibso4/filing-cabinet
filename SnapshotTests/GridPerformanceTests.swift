import Core
import Foundation
import Library
import ScreenModels
import Screens
import SwiftUI
import TestSupport
import Testing
import UIKit

/// The grid stays lazy over a large library: it asks for what is near the screen, and only ever page 0. The test sleeps
/// between steps, so the main actor runs as it does in the app, rather than spinning a nested run loop in its own job.
@MainActor
struct GridPerformanceTests {
    private static let scanCount = 2_000
    private static let firstScreenful = 18
    /// What fits on the 402 x 874 window under the bar as it opens, expanded: four rows of three.
    private static let visibleTiles = 12
    /// The row the bar's collapse brings into view as the header settles small: already in the window, but loaded as
    /// it appears, in any order.
    private static let settlingRowTiles = 3
    /// `GridPrefetchWindow`'s run past the last visible tile.
    private static let prefetchedTiles = 36
    private static let maxPerStep = 60

    @Test func gridWithTwoThousandScansStaysBoundedWhileScrolling() async throws {
        let thumbnails = FakeThumbnails()
        let scans = Self.scans()
        let view = Self.allScans(scans, thumbnails: thumbnails)

        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        defer {
            window.rootViewController = nil
            window.isHidden = true
        }
        window.rootViewController = UIHostingController(rootView: view)
        window.makeKeyAndVisible()

        try await Self.waitForFirstLoad { thumbnails.loadedRequests.count }
        let firstScreen = thumbnails.loadedRequests.count
        #expect(firstScreen >= Self.firstScreenful)
        #expect(firstScreen <= Self.maxPerStep)
        // The visible tiles and the window, and nothing else; the window in order among themselves (past the row the
        // settling brings into view). That no prefetch comes before the layout pass ends is proved with scripted
        // events in `GridPrefetcherTests`.
        let prefetchEnd = Self.visibleTiles + Self.prefetchedTiles
        let firstIDs = Self.distinct(thumbnails.loadedRequests.map(\.id)).prefix(prefetchEnd)
        #expect(Set(firstIDs) == Set(scans.prefix(prefetchEnd).map(\.id)))
        let prefetchWindow = scans[(Self.visibleTiles + Self.settlingRowTiles)..<prefetchEnd].map(\.id)
        #expect(firstIDs.filter(prefetchWindow.contains) == prefetchWindow)

        let scrollView = try #require(Self.firstScrollView(in: window))
        var seen = thumbnails.loadedRequests.count
        var largestStep = 0
        var steps = 0

        func step(to offset: CGFloat) async throws {
            scrollView.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
            try await Task.sleep(for: .milliseconds(100))
            let requests = thumbnails.loadedRequests
            let distinct = Set(requests[seen...].map(\.id)).count
            seen = requests.count
            largestStep = max(largestStep, distinct)
            steps += 1
            #expect(distinct <= Self.maxPerStep)
        }

        let end = try await Self.scrollToEndAndBack(scrollView, stride: window.bounds.height, step: step)
        #expect(try thumbnails.loadedIDs.contains(#require(scans.last).id))

        #expect(thumbnails.loadedRequests.allSatisfy { $0.page == 0 })
        Attachment.record(
            """
            first screen: \(firstScreen) loaded requests
            steps: \(steps), end offset: \(Int(end))
            largest step: \(largestStep) distinct ids
            total: \(thumbnails.loadedRequests.count) loaded requests, \(thumbnails.loadedIDs.count) distinct ids
            """, named: "grid-performance.txt")
    }

    /// Calls `step` with each offset, one screen apart, down to the end and back to the top; returns the end's offset.
    /// The lazy grid's content size firms up as it goes, so the end is read again at each step.
    private static func scrollToEndAndBack(
        _ scrollView: UIScrollView, stride: CGFloat, step: (CGFloat) async throws -> Void
    ) async throws -> CGFloat {
        var offset: CGFloat = 0
        while offset < maxOffset(of: scrollView) {
            offset = min(offset + stride, maxOffset(of: scrollView))
            try await step(offset)
        }
        let end = offset
        while offset > 0 {
            offset = max(offset - stride, 0)
            try await step(offset)
        }
        return end
    }

    /// All Scans in a navigation stack, as in the app: the grid's header lives in the bar, and rests small by collapsing
    /// it.
    private static func allScans(_ scans: [ScanSummary], thumbnails: FakeThumbnails) -> some View {
        let library = FakeLibrary(scans: scans)
        let model = CollectionGridModel(
            kind: .all, library: library, today: Today(clock: Fixtures.clock), calendar: Fixtures.clock.calendar)
        return NavigationStack {
            CollectionGridView(model: model, thumbnails: thumbnails, canScan: true, onOpen: { _ in }, onScan: {})
        }
    }

    /// Each ID once, in the order first asked for. Distinct, as every scroll step counts them: the header settling small
    /// moves the content under the bar once, so the last visible row disappears and comes back, asking again.
    private static func distinct(_ ids: [ScanID]) -> [ScanID] {
        var asked: Set<ScanID> = []
        return ids.filter { asked.insert($0).inserted }
    }

    /// 2,000 forever-kept scans, a minute apart so the order is fixed.
    private static func scans() -> [ScanSummary] {
        let now = Fixtures.clock.now()
        return (0..<scanCount).map { index in
            ScanSummary(
                id: ScanID(),
                title: "Scan \(index)",
                collection: .notes,
                scannedAt: now.addingTimeInterval(Double(-index) * 60),
                expiryOverride: nil,
                pageCount: 1)
        }
    }

    /// Waits for the first screen and its prefetch, then a moment longer to catch anything past them. Prefetching is
    /// low priority, so on a busy machine it can start well after the visible tiles; the wait ends at a deadline, and
    /// the bounds then judge what arrived.
    private static func waitForFirstLoad(_ count: () -> Int) async throws {
        let deadline = ContinuousClock.now + .seconds(20)
        while count() < visibleTiles + prefetchedTiles, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        try await Task.sleep(for: .milliseconds(500))
    }

    private static func maxOffset(of scrollView: UIScrollView) -> CGFloat {
        max(0, scrollView.contentSize.height + scrollView.adjustedContentInset.bottom - scrollView.bounds.height)
    }

    private static func firstScrollView(in view: UIView) -> UIScrollView? {
        if let scrollView = view as? UIScrollView { return scrollView }
        for subview in view.subviews {
            if let found = firstScrollView(in: subview) { return found }
        }
        return nil
    }
}
