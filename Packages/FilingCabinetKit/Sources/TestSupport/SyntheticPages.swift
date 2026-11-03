import CoreGraphics
import CoreText
import Foundation

/// Made-up pages rendered with Core Text, black on white. Never personal documents.
public enum SyntheticPages {
    private static let margin: CGFloat = 200
    private static let lineSpacing: CGFloat = 1.5

    /// Renders `lines` top to bottom; each pair is the text and its point size (in pixels at 1:1).
    /// The default size is A4 at 300 dpi, close to a VisionKit page.
    package static func page(lines: [(String, CGFloat)], size: CGSize = CGSize(width: 2480, height: 3508)) -> CGImage {
        let context = whiteContext(size)
        var baseline = size.height - margin
        for (text, pointSize) in lines {
            baseline -= pointSize
            let font = CTFontCreateWithName("Helvetica" as CFString, pointSize, nil)
            let attributed = NSAttributedString(
                string: text,
                attributes: [
                    NSAttributedString.Key(kCTFontAttributeName as String): font,
                    NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1),
                ])
            context.textPosition = CGPoint(x: margin, y: baseline)
            CTLineDraw(CTLineCreateWithAttributedString(attributed), context)
            baseline -= pointSize * (lineSpacing - 1)
        }
        return image(from: context)
    }

    /// "CITY PHARMACY" in large type, then two small lines.
    public static func receipt() -> CGImage {
        page(lines: [("CITY PHARMACY", 160), ("Batteries AA", 60), ("TOTAL 12.40", 60)])
    }

    /// An empty white page.
    package static func blank() -> CGImage {
        page(lines: [])
    }

    private static func whiteContext(_ size: CGSize) -> CGContext {
        guard
            let context = CGContext(
                data: nil,
                width: Int(size.width),
                height: Int(size.height),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            )
        else { preconditionFailure("SyntheticPages: could not create a \(size) bitmap context") }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))
        return context
    }

    private static func image(from context: CGContext) -> CGImage {
        guard let image = context.makeImage() else { preconditionFailure("SyntheticPages: could not make an image") }
        return image
    }
}
