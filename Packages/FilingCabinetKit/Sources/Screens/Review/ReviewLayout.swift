import SwiftUI

/// Review's two parts, top and bottom: the scan, and the sheet. The sheet gets its ideal height when there is room;
/// at large text sizes it gets what is left once the scan has its minimum height, and its content scrolls.
struct ReviewLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let top = subviews[0]
        let sheet = subviews[1]
        let topMinimum = top.sizeThatFits(ProposedViewSize(width: bounds.width, height: 0)).height
        let sheetIdeal = sheet.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)).height
        let sheetHeight = min(sheetIdeal, max(0, bounds.height - topMinimum))
        top.place(
            at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: bounds.height - sheetHeight))
        sheet.place(
            at: CGPoint(x: bounds.minX, y: bounds.maxY - sheetHeight),
            proposal: ProposedViewSize(width: bounds.width, height: sheetHeight)
        )
    }
}
