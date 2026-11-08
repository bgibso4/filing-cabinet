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
            analytics: RecordingAnalytics())
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
                analytics: RecordingAnalytics())
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
