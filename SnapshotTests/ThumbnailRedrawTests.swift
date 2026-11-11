import Core
import CoreGraphics
import Library
import ScreenModels
import Screens
import SwiftUI
import Synchronization
import TestSupport
import Testing
import UIKit

/// A prefetch can fill the cache between a tile's first read of it and its load task starting. The tile has to show
/// that thumbnail. Hosted in a real window, because `.task` and the redraw only run there.
@MainActor
struct ThumbnailRedrawTests {
    private static let deadline = Duration.seconds(3)

    @Test func aThumbnailCachedJustAfterTheFirstReadStillShows() async throws {
        let scan = ScanSummary(
            id: ScanID(),
            title: "Scan",
            collection: .notes,
            scannedAt: Fixtures.clock.now(),
            expiryOverride: nil,
            pageCount: 1)
        let model = CollectionGridModel(
            kind: .all,
            library: FakeLibrary(scans: [scan]),
            today: Today(clock: Fixtures.clock),
            calendar: Fixtures.clock.calendar,
            analytics: RecordingAnalytics(),
            export: Fixtures.export)
        let picture = try #require(WindowPixels.image(.magenta))
        let view = CollectionGridView(
            model: model,
            thumbnails: CachedAfterFirstRead(image: picture),
            canScan: true,
            onOpen: { _ in },
            onScan: {})

        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        defer {
            window.rootViewController = nil
            window.isHidden = true
        }
        window.rootViewController = UIHostingController(rootView: view)
        window.makeKeyAndVisible()

        let end = ContinuousClock.now + Self.deadline
        var shows = false
        while !shows, ContinuousClock.now < end {
            try await Task.sleep(for: .milliseconds(100))
            shows = try WindowPixels.shows(.magenta, in: window)
        }
        #expect(shows)
    }
}

/// The race, on demand: the first cache read misses and every later one hits. A load finds nothing, so the only way to
/// show the picture is from the cache.
private nonisolated final class CachedAfterFirstRead: ThumbnailProviding {
    private let image: CGImage
    private let reads = Mutex(0)

    init(image: CGImage) {
        self.image = image
    }

    func cachedThumbnail(for id: ScanID, page: Int) -> CGImage? {
        let isFirst = reads.withLock { reads in
            reads += 1
            return reads == 1
        }
        return isFirst ? nil : image
    }

    func thumbnail(for id: ScanID, page: Int) async -> CGImage? { nil }
}
