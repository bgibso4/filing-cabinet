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
            calendar: Fixtures.clock.calendar)
        let picture = try #require(Self.magentaImage())
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
            shows = try Self.showsMagenta(window)
        }
        #expect(shows)
    }

    private static func magentaImage() -> CGImage? {
        let context = CGContext(
            data: nil,
            width: 4,
            height: 4,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 1, alpha: 1))
        context?.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        return context?.makeImage()
    }

    /// Whether any of the window's pixels is the picture's colour; nothing else on the screen is close to it.
    private static func showsMagenta(_ window: UIWindow) throws -> Bool {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let image = try #require(rendered.cgImage)
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try #require(
            CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return stride(from: 0, to: pixels.count, by: 4).contains { offset in
            pixels[offset] > 200 && pixels[offset + 1] < 60 && pixels[offset + 2] > 200
        }
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
