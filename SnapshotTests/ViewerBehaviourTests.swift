import Core
import CoreGraphics
import Library
import Observation
import ScreenModels
import Screens
import SwiftUI
import Synchronization
import TestSupport
import Testing
import UIKit

/// What only shows in a real window: `.task`, redraws, the pager and the navigation stack.
@MainActor
struct ViewerBehaviourTests {
    private static let deadline = Duration.seconds(5)
    /// The default-size Details panel (07-01).
    private static let panelHeight: CGFloat = 236
    /// The bar's middle, where the pill sits and nothing else does: clear of the back button and above the page.
    private static let pillBand = CGRect(x: 100, y: 62, width: 202, height: 44)

    private func scan(pages: Int) -> ScanSummary {
        ScanSummary(
            id: ScanID(),
            title: "Scan",
            collection: .documents,
            scannedAt: Fixtures.clock.now(),
            expiryOverride: nil,
            pageCount: pages)
    }

    private func model(_ scan: ScanSummary) -> ViewerModel {
        ViewerModel(
            id: scan.id,
            library: FakeLibrary(scans: [scan]),
            today: Today(clock: Fixtures.clock),
            calendar: Fixtures.clock.calendar,
            analytics: RecordingAnalytics(),
            history: Fixtures.searchHistory())
    }

    private func host(_ view: some View) throws -> UIWindow {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        window.rootViewController = UIHostingController(rootView: view)
        window.makeKeyAndVisible()
        return window
    }

    private func close(_ window: UIWindow) {
        window.rootViewController = nil
        window.isHidden = true
    }

    /// The page's image on screen, in window coordinates.
    private func pageFrame(in window: UIWindow) -> CGRect? {
        func page(in view: UIView) -> UIImageView? {
            if let image = view as? UIImageView, image.image != nil, view.superview is UIScrollView,
                !image.bounds.isEmpty
            {
                return image
            }
            return view.subviews.lazy.compactMap { page(in: $0) }.first
        }
        return page(in: window).map { $0.convert($0.bounds, to: window) }
    }

    /// Polls until `condition` holds; false if it never did.
    private func eventually(_ condition: () throws -> Bool) async throws -> Bool {
        let end = ContinuousClock.now + Self.deadline
        while ContinuousClock.now < end {
            if try condition() { return true }
            try await Task.sleep(for: .milliseconds(100))
        }
        return false
    }

    @Test func aPageCachedJustAfterTheFirstReadStillShows() async throws {
        let scan = scan(pages: 1)
        let picture = try #require(WindowPixels.image(.magenta))
        let view = ViewerView(
            model: model(scan), pages: CachedAfterFirstRead(image: picture), thumbnails: FakeThumbnails())
        let window = try host(view)
        defer { close(window) }
        #expect(try await eventually { try WindowPixels.shows(.magenta, in: window) })
    }

    @Test func thePageSurvivesTheDestinationBeingEvaluatedAgain() async throws {
        let scan = scan(pages: 2)
        let pages = FakePageImages(images: [
            scan.id: [
                0: try #require(WindowPixels.image(.cyan)),
                1: try #require(WindowPixels.image(.magenta)),
            ]
        ])
        let library = FakeLibrary(scans: [scan])
        let today = Today(clock: Fixtures.clock)
        let ticks = Ticks()
        let made = MadeModels()
        let view = ReevaluatedRoute(ticks: ticks) {
            let model = ViewerModel(
                id: scan.id,
                library: library,
                today: today,
                calendar: Fixtures.clock.calendar,
                analytics: RecordingAnalytics(),
                history: Fixtures.searchHistory())
            made.models.append(model)
            return model
        } content: { makeModel in
            ViewerRoute(
                makeModel: makeModel,
                makeDetails: {
                    DetailsModel(
                        id: scan.id,
                        library: library,
                        today: today,
                        clock: Fixtures.clock,
                        analytics: RecordingAnalytics())
                },
                pages: pages,
                thumbnails: FakeThumbnails())
        }
        let window = try host(view)
        defer { close(window) }

        #expect(try await eventually { try WindowPixels.shows(.cyan, in: window) })
        let first = try #require(made.models.first)
        first.currentPage = 1
        #expect(try await eventually { try WindowPixels.shows(.magenta, in: window) })

        let built = made.models.count
        ticks.value += 1
        #expect(try await eventually { made.models.count > built })
        try await Task.sleep(for: .milliseconds(500))
        #expect(try WindowPixels.shows(.magenta, in: window))
        #expect(try !WindowPixels.shows(.cyan, in: window))
    }

    @Test func aFarPageIsNeverAskedFor() async throws {
        let scan = scan(pages: 20)
        let pages = FakePageImages(images: [
            scan.id: Dictionary(
                uniqueKeysWithValues: try (0..<20).map { ($0, try #require(WindowPixels.image(.cyan))) })
        ])
        let model = model(scan)
        let window = try host(ViewerView(model: model, pages: pages, thumbnails: FakeThumbnails()))
        defer { close(window) }

        #expect(try await eventually { pages.requests.contains { $0.page == 1 && $0.kind == .loaded } })
        model.currentPage = 10
        #expect(try await eventually { pages.requests.contains { $0.page == 11 && $0.kind == .loaded } })
        try await Task.sleep(for: .milliseconds(500))
        let asked = Set(pages.requests.map(\.page))
        #expect(asked.isSubset(of: [0, 1, 9, 10, 11]), "\(asked.sorted())")
    }

    /// #61: the page's fit follows Details' progress every frame, and the pill fades rather than leaving the bar.
    @Test func pageFollowsDetailsProgress() async throws {
        let scan = scan(pages: 1)
        let pages = FakePageImages(images: [scan.id: [0: try #require(WindowPixels.image(.magenta))]])
        let progress = DetailsProgress()
        let viewer = model(scan)
        let window = try host(
            NavigationStack(path: .constant([0])) {
                Color.clear.navigationDestination(for: Int.self) { _ in
                    ProgressViewer(model: viewer, pages: pages, height: Self.panelHeight, progress: progress)
                }
            })
        defer { close(window) }
        #expect(try await eventually { pageFrame(in: window) != nil })

        var bottoms: [CGFloat] = []
        var pills: [[UInt8]] = []
        for value: CGFloat in [0, 0.5, 1] {
            progress.value = value
            // Settled: the page has moved from where it was, and two reads in a row agree on the page and the bar.
            var last: (bottom: CGFloat, pill: [UInt8])?
            let settled = try await eventually {
                let read = (
                    bottom: try #require(pageFrame(in: window)).maxY,
                    pill: try WindowPixels.rgba(of: window, in: Self.pillBand)
                )
                defer { last = read }
                return read.bottom != bottoms.last && last.map { $0 == read } == true
            }
            #expect(settled, "progress \(value)")
            let reading = try #require(last)
            bottoms.append(reading.bottom)
            pills.append(reading.pill)
        }
        #expect(bottoms[0] > bottoms[1] && bottoms[1] > bottoms[2], "\(bottoms)")
        #expect(abs(bottoms[1] - (bottoms[0] + bottoms[2]) / 2) <= 1, "\(bottoms)")
        // The pill shows at 0 and is gone at 1; at 0.5 it is half as far from gone.
        let shown = WindowPixels.difference(pills[0], pills[2])
        #expect(shown > 0)
        let half = Double(WindowPixels.difference(pills[1], pills[2])) / Double(max(shown, 1))
        #expect(abs(half - 0.5) < 0.1, "\(half)")
    }

    @Test func aMissingScanPops() async throws {
        let expired = ScanSummary(
            id: ScanID(),
            title: "Old",
            collection: .throwaways,
            scannedAt: Fixtures.clock.calendar.date(byAdding: .day, value: -30, to: Fixtures.clock.now())
                ?? Fixtures.clock.now(),
            expiryOverride: nil,
            pageCount: 1)
        let path = PushedPath()
        let model = model(expired)
        let window = try host(PushedViewer(path: path, model: model))
        defer { close(window) }
        #expect(try await eventually { path.value.isEmpty })
    }
}

/// Something to change, so a parent's body runs again as `RootView`'s does when the flow's phase moves.
@Observable
@MainActor
private final class Ticks {
    var value = 0
}

@MainActor
private final class MadeModels {
    var models: [ViewerModel] = []
}

/// Builds the route anew on every tick, the way `RootView.destination` does.
private struct ReevaluatedRoute<Content: View>: View {
    let ticks: Ticks
    let makeModel: () -> ViewerModel
    let content: (() -> ViewerModel) -> Content

    init(
        ticks: Ticks,
        makeModel: @escaping () -> ViewerModel,
        @ViewBuilder content: @escaping (() -> ViewerModel) -> Content
    ) {
        self.ticks = ticks
        self.makeModel = makeModel
        self.content = content
    }

    var body: some View {
        // Reading the tick is what runs this body again.
        _ = ticks.value
        return content(makeModel)
    }
}

@Observable
@MainActor
private final class DetailsProgress {
    var value: CGFloat = 0
}

/// The viewer with Details' progress changed in place, as `ViewerRoute` changes it every frame.
private struct ProgressViewer: View {
    let model: ViewerModel
    let pages: FakePageImages
    let height: CGFloat
    let progress: DetailsProgress

    var body: some View {
        ViewerView(
            model: model,
            pages: pages,
            thumbnails: FakeThumbnails(),
            detailsHeight: height,
            detailsProgress: progress.value)
    }
}

@Observable
@MainActor
private final class PushedPath {
    var value = [0]
}

private struct PushedViewer: View {
    @Bindable var path: PushedPath
    let model: ViewerModel

    var body: some View {
        NavigationStack(path: $path.value) {
            Color.clear.navigationDestination(for: Int.self) { _ in
                ViewerView(model: model, pages: FakePageImages(), thumbnails: FakeThumbnails())
            }
        }
    }
}

/// The race, on demand: the first cache read misses and every later one hits. A load finds nothing, so the only way to
/// show the picture is from the cache.
private nonisolated final class CachedAfterFirstRead: PageImageProviding {
    private let image: CGImage
    private let reads = Mutex(0)

    init(image: CGImage) {
        self.image = image
    }

    func cachedPage(for id: ScanID, index: Int) -> CGImage? {
        let isFirst = reads.withLock { reads in
            reads += 1
            return reads == 1
        }
        return isFirst ? nil : image
    }

    func page(for id: ScanID, index: Int) async -> CGImage? { nil }
}
