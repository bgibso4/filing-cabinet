import CoreGraphics
import Foundation
import ImageIO
import XCTest

/// The five synthetic scans bundled with the device tests, upscaled to the size of a real VisionKit page.
enum DeviceFixtures {
    /// The fixture every cold read uses.
    static let coldPage = "scan-r-pharmacy"
    /// The pages the per-page timing reads, in order.
    static let pages = ["scan-r-pharmacy", "scan-lease", "scan-lease-p2", "scan-note-bio", "scan-insurance"]

    /// A VisionKit page is about A4 at 300 dpi; the fixtures are 360 to 720 px wide.
    private static let pageSize = CGSize(width: 2480, height: 3508)

    /// The named fixture, aspect-fitted into 2480 × 3508.
    static func page(_ name: String) throws -> CGImage {
        let url = try XCTUnwrap(
            Bundle(for: BundleToken.self).url(forResource: name, withExtension: "jpg"), "\(name).jpg is not bundled")
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil), "can't open \(name).jpg")
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil), "can't decode \(name).jpg")
        return try upscaled(image)
    }

    /// Milliseconds in a duration.
    static func milliseconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15
    }

    private static func upscaled(_ image: CGImage) throws -> CGImage {
        let scale = min(pageSize.width / CGFloat(image.width), pageSize.height / CGFloat(image.height))
        let width = Int((CGFloat(image.width) * scale).rounded())
        let height = Int((CGFloat(image.height) * scale).rounded())
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue
        let context = try XCTUnwrap(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: space,
                bitmapInfo: bitmapInfo
            ))
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return try XCTUnwrap(context.makeImage())
    }

    /// Finds the test bundle.
    private final class BundleToken {}
}
