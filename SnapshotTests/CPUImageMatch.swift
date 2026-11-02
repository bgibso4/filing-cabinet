import CoreGraphics
import Foundation
import UIKit

/// A CPU check run before swift-snapshot-testing's own comparison.
///
/// The library's perceptual comparison runs on Core Image and Metal. On the GitHub-hosted macOS runners (virtual
/// machines with a paravirtual GPU) it reported 0.9% of Home's pixels as changed when the rendered image differed
/// from the reference by one pixel at 1/255. This check passes only if every pixel is within the same delta E
/// threshold the library uses, measured with CIE76, which is never smaller than the library's CIE94: it can't pass
/// anything the library would fail on correct hardware. Anything it rejects still goes to the library's comparison
/// for the failure message and diff images.
enum CPUImageMatch {
    /// Bytes per RGBA pixel in the comparison buffers.
    private static let bytesPerPixel = 4

    /// True when both images have the same size and every pixel's CIE76 delta E is at most
    /// `(1 - perceptualPrecision) * 100`, matching the library's threshold for a pixel precision of 1. The new image
    /// is compared after a PNG round trip, as the library does, so it is the image written to disk.
    static func matches(_ old: UIImage, _ new: UIImage, perceptualPrecision: Float) -> Bool {
        guard
            let oldImage = old.cgImage,
            let newImage = new.pngData().flatMap(UIImage.init(data:))?.cgImage,
            oldImage.width == newImage.width, oldImage.height == newImage.height,
            let oldPixels = rgbaPixels(of: oldImage),
            let newPixels = rgbaPixels(of: newImage)
        else { return false }

        let threshold = Double(1 - perceptualPrecision) * 100
        var offset = 0
        while offset < oldPixels.count {
            defer { offset += bytesPerPixel }
            if oldPixels[offset..<offset + bytesPerPixel] == newPixels[offset..<offset + bytesPerPixel] { continue }
            if oldPixels[offset + 3] != newPixels[offset + 3] { return false }
            let deltaE = Lab(oldPixels, at: offset).distance(to: Lab(newPixels, at: offset))
            if deltaE > threshold { return false }
        }
        return true
    }

    /// The image drawn into an 8-bit sRGB RGBA buffer, so both images are compared in one colour space.
    private static func rgbaPixels(of image: CGImage) -> [UInt8]? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let rowBytes = image.width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: rowBytes * image.height)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard
                let context = CGContext(
                    data: buffer.baseAddress,
                    width: image.width,
                    height: image.height,
                    bitsPerComponent: 8,
                    bytesPerRow: rowBytes,
                    space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        return drawn ? pixels : nil
    }
}

/// A CIE L*a*b* colour (D65 white point) converted from an 8-bit sRGB pixel.
private struct Lab {
    let lightness: Double
    let greenRed: Double
    let blueYellow: Double

    // sRGB → XYZ (D65) matrix rows and the D65 reference white, from IEC 61966-2-1.
    private static let toX = (0.4124564, 0.3575761, 0.1804375)
    private static let toY = (0.2126729, 0.7151522, 0.0721750)
    private static let toZ = (0.0193339, 0.1191920, 0.9503041)
    private static let white = (x: 0.95047, y: 1.0, z: 1.08883)

    init(_ pixels: [UInt8], at offset: Int) {
        let red = Self.linear(pixels[offset])
        let green = Self.linear(pixels[offset + 1])
        let blue = Self.linear(pixels[offset + 2])
        let xValue = Self.toX.0 * red + Self.toX.1 * green + Self.toX.2 * blue
        let yValue = Self.toY.0 * red + Self.toY.1 * green + Self.toY.2 * blue
        let zValue = Self.toZ.0 * red + Self.toZ.1 * green + Self.toZ.2 * blue
        let fromX = Self.compand(xValue / Self.white.x)
        let fromY = Self.compand(yValue / Self.white.y)
        let fromZ = Self.compand(zValue / Self.white.z)
        lightness = 116 * fromY - 16
        greenRed = 500 * (fromX - fromY)
        blueYellow = 200 * (fromY - fromZ)
    }

    /// CIE76 delta E: the Euclidean distance in L*a*b*.
    func distance(to other: Self) -> Double {
        let lightnessDelta = lightness - other.lightness
        let greenRedDelta = greenRed - other.greenRed
        let blueYellowDelta = blueYellow - other.blueYellow
        return (lightnessDelta * lightnessDelta + greenRedDelta * greenRedDelta + blueYellowDelta * blueYellowDelta)
            .squareRoot()
    }

    /// The sRGB transfer function, inverted.
    private static func linear(_ component: UInt8) -> Double {
        let value = Double(component) / 255
        return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }

    /// The CIE L*a*b* companding function.
    private static func compand(_ ratio: Double) -> Double {
        let epsilon = 216.0 / 24389.0
        let kappa = 24389.0 / 27.0
        return ratio > epsilon ? cbrt(ratio) : (kappa * ratio + 16) / 116
    }
}
