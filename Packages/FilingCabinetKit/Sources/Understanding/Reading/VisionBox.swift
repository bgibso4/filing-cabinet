import CoreGraphics

/// Vision's normalized rectangles have their origin at the bottom-left; ours have it at the top-left.
enum VisionBox {
    static func topLeft(fromBottomLeft rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: 1 - rect.maxY, width: rect.width, height: rect.height)
    }
}
