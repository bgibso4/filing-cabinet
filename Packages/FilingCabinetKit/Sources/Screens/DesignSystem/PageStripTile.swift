import SwiftUI

/// The size every page strip gives a page.
enum PageStripTile {
    // Review.dc.html line 399, ScanView.dc.html line 372: the current page is 34 by 44 pt with 6 pt either side; the
    // others are 26 by 36 pt.
    static let currentSize = CGSize(width: 34, height: 44)
    static let otherSize = CGSize(width: 26, height: 36)
    static let currentMargin: CGFloat = 6
}

extension View {
    func pageStripTile(isCurrent: Bool) -> some View {
        let size = isCurrent ? PageStripTile.currentSize : PageStripTile.otherSize
        return
            self
            .frame(width: size.width, height: size.height, alignment: .top)
            .clipShape(.rect(cornerRadius: Tokens.Radius.nested))
            .padding(.horizontal, isCurrent ? PageStripTile.currentMargin : 0)
    }
}
