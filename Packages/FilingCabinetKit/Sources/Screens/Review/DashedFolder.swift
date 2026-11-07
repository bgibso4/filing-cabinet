import SwiftUI

/// The empty Collection row's icon: a folder outline drawn in dashes (Review.dc.html line 293, a 28 by 22 viewBox).
struct DashedFolder: View {
    // Review.dc.html line 293: 26 by 21 pt, a 1.6 pt stroke in 3 pt dashes with 2.5 pt gaps.
    private static let size = CGSize(width: 26, height: 21)
    private static let style = StrokeStyle(lineWidth: 1.6, dash: [3, 2.5])

    var body: some View {
        FolderShape()
            .stroke(Tokens.Color.textSecondary, style: Self.style)
            .frame(width: Self.size.width, height: Self.size.height)
    }

    /// The mock's path, scaled from its 28 by 22 viewBox.
    nonisolated private struct FolderShape: Shape {
        func path(in rect: CGRect) -> Path {
            let scaleX = rect.width / 28
            let scaleY = rect.height / 22
            func point(_ across: CGFloat, _ down: CGFloat) -> CGPoint {
                CGPoint(x: rect.minX + across * scaleX, y: rect.minY + down * scaleY)
            }
            var path = Path()
            path.move(to: point(1, 3.5))
            path.addQuadCurve(to: point(3.5, 1), control: point(1, 1))
            path.addLine(to: point(9.3, 1))
            path.addQuadCurve(to: point(11.2, 1.9), control: point(10.4, 1))
            path.addLine(to: point(12.6, 3.5))
            path.addLine(to: point(24.5, 3.5))
            path.addQuadCurve(to: point(27, 6), control: point(27, 3.5))
            path.addLine(to: point(27, 18.5))
            path.addQuadCurve(to: point(24.5, 21), control: point(27, 21))
            path.addLine(to: point(3.5, 21))
            path.addQuadCurve(to: point(1, 18.5), control: point(1, 21))
            path.closeSubpath()
            return path
        }
    }
}
