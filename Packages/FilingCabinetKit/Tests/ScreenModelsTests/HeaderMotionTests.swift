import CoreGraphics
import Testing

@testable import ScreenModels

@Test func shortContentStillRestsSmall() {
    // Content one viewport tall plus the large title's height always leaves room to scroll it away.
    #expect(HeaderMotion(largeHeight: 52).minimumContentHeight(viewport: 700) == 752)
}
