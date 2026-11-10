import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// HEIC originals and JPEG thumbnails through ImageIO only (M12).
enum ImageCoding {
    enum CodingError: Error {
        case encodeFailed
    }

    /// Encodes `image` as HEIC at `quality` (0...1).
    static func heic(_ image: CGImage, quality: Double) throws -> Data {
        try encode(image, as: .heic, quality: quality)
    }

    /// Encodes `image` as JPEG at `quality` (0...1), for a PDF page.
    static func jpeg(_ image: CGImage, quality: Double) throws -> Data {
        try encode(image, as: .jpeg, quality: quality)
    }

    /// Scales `image` so its long edge is at most `maxPixel`, then encodes JPEG at quality 0.8.
    static func jpegThumbnail(_ image: CGImage, maxPixel: Int) throws -> Data {
        try encode(scaled(image, maxPixel: maxPixel), as: .jpeg, quality: thumbnailQuality)
    }

    /// M12: thumbnails are JPEG at 0.8.
    private static let thumbnailQuality = 0.8

    private static func encode(_ image: CGImage, as type: UTType, quality: Double) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else {
            throw CodingError.encodeFailed
        }
        let options = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        CGImageDestinationAddImage(destination, image, options)
        guard CGImageDestinationFinalize(destination) else { throw CodingError.encodeFailed }
        return data as Data
    }

    private static func scaled(_ image: CGImage, maxPixel: Int) throws -> CGImage {
        let longEdge = max(image.width, image.height)
        guard longEdge > maxPixel else { return image }
        let scale = Double(maxPixel) / Double(longEdge)
        let width = max(1, Int((Double(image.width) * scale).rounded(.down)))
        let height = max(1, Int((Double(image.height) * scale).rounded(.down)))
        guard
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            )
        else { throw CodingError.encodeFailed }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let result = context.makeImage() else { throw CodingError.encodeFailed }
        return result
    }
}
