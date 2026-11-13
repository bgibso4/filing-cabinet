import CoreGraphics

/// Page 1 made small enough to send to the model (M2).
package enum SuggestionImage {
    /// The page aspect-fitted to `longSide` on its long side, or the page itself when it is already that small.
    /// Nil when drawing fails.
    package static func fitted(_ page: CGImage, longSide: Int) -> CGImage? {
        let long = max(page.width, page.height)
        guard long > longSide else { return page }
        let scale = Double(longSide) / Double(long)
        let width = Int((Double(page.width) * scale).rounded())
        let height = Int((Double(page.height) * scale).rounded())
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: space,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            )
        else { return nil }
        context.interpolationQuality = .high
        context.draw(page, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
