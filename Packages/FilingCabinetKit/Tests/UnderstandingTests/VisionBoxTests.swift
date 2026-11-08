import CoreGraphics
import Testing

@testable import Understanding

@Test func bottomLeftBoxNearTheTopMovesToASmallTopLeftY() {
    let vision = CGRect(x: 0.1, y: 0.8, width: 0.5, height: 0.1)

    let ours = VisionBox.topLeft(fromBottomLeft: vision)

    #expect(abs(ours.minX - 0.1) < 1e-9)
    #expect(abs(ours.minY - 0.1) < 1e-9)
    #expect(abs(ours.width - 0.5) < 1e-9)
    #expect(abs(ours.height - 0.1) < 1e-9)
}

@Test func fullPageBoxIsUnchanged() {
    let full = CGRect(x: 0, y: 0, width: 1, height: 1)

    #expect(VisionBox.topLeft(fromBottomLeft: full) == full)
}
