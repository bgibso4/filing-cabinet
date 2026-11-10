import CoreGraphics
import UIKit

/// Tells which picture a hosted window is showing, from pictures in one colour that nothing else on the screen is close
/// to.
@MainActor
enum WindowPixels {
    enum Colour {
        case magenta
        case cyan

        fileprivate var cgColor: CGColor {
            switch self {
            case .magenta: CGColor(srgbRed: 1, green: 0, blue: 1, alpha: 1)
            case .cyan: CGColor(srgbRed: 0, green: 1, blue: 1, alpha: 1)
            }
        }

        fileprivate func matches(red: UInt8, green: UInt8, blue: UInt8) -> Bool {
            switch self {
            case .magenta: red > 200 && green < 60 && blue > 200
            case .cyan: red < 60 && green > 200 && blue > 200
            }
        }
    }

    static func image(_ colour: Colour) -> CGImage? {
        let context = CGContext(
            data: nil,
            width: 4,
            height: 4,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.setFillColor(colour.cgColor)
        context?.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        return context?.makeImage()
    }

    /// Whether any of the window's pixels is the colour.
    static func shows(_ colour: Colour, in window: UIWindow) throws -> Bool {
        let pixels = try rgba(of: window, in: window.bounds)
        return stride(from: 0, to: pixels.count, by: 4).contains { offset in
            colour.matches(red: pixels[offset], green: pixels[offset + 1], blue: pixels[offset + 2])
        }
    }

    /// The summed per-channel difference between two renderings of the same area, from `rgba`.
    static func difference(_ first: [UInt8], _ second: [UInt8]) -> Int {
        zip(first, second).reduce(0) { sum, pair in sum + abs(Int(pair.0) - Int(pair.1)) }
    }

    /// The window's pixels in `rect`, at one pixel a point, as RGBA bytes.
    static func rgba(of window: UIWindow, in rect: CGRect) throws -> [UInt8] {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(bounds: rect, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        guard let image = rendered.cgImage else { throw NoRenderedImage() }
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard
            let context = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw NoRenderedImage() }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }

    private struct NoRenderedImage: Error {}
}
