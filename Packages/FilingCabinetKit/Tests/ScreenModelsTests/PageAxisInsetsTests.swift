import CoreGraphics
import Testing

@testable import ScreenModels

// The viewer's numbers: an 874 pt screen whose page fits between 120 pt from the top and 164 pt from the bottom.
private let screen: CGFloat = 874
private let fitTop: CGFloat = 120
private let fitBottom: CGFloat = 164
private let region = screen - fitTop - fitBottom

private func insets(_ content: CGFloat) -> PageAxisInsets {
    PageAxisInsets(content: content, bounds: screen, fitLeading: fitTop, fitTrailing: fitBottom)
}

@Test func aFittedPageIsCentredBetweenTheControls() {
    #expect(insets(region - 100) == PageAxisInsets(leading: fitTop + 50, trailing: fitBottom + 50))
}

@Test func aPageThatJustFillsTheRegionStopsAtTheControls() {
    #expect(insets(region) == PageAxisInsets(leading: fitTop, trailing: fitBottom))
}

@Test func aPageAsBigAsTheScreenReachesBothEdges() {
    #expect(insets(screen) == PageAxisInsets(leading: 0, trailing: 0))
    #expect(insets(screen * 3) == PageAxisInsets(leading: 0, trailing: 0))
}

@Test func betweenTheRegionAndTheScreenTheSpareRoomKeepsTheControlsProportions() {
    // Half way from the region to the screen: half the controls' room is left, split 120 to 164.
    let spare = (fitTop + fitBottom) / 2
    #expect(insets(screen - spare) == PageAxisInsets(leading: fitTop / 2, trailing: fitBottom / 2))
}

@Test func growingThePageNeverJumps() {
    // Zooming moves the page smoothly: a point more of page moves its edge by at most a point.
    var previous = insets(region - 200)
    for content in stride(from: region - 199, through: screen + 50, by: 1) {
        let next = insets(content)
        #expect(abs(next.leading - previous.leading) <= 1, "leading jumped at \(content)")
        #expect(abs(next.trailing - previous.trailing) <= 1, "trailing jumped at \(content)")
        previous = next
    }
}

@Test func withoutFitInsetsAPageIsSimplyCentred() {
    let across = PageAxisInsets(content: 300, bounds: 402, fitLeading: 0, fitTrailing: 0)
    #expect(across == PageAxisInsets(leading: 51, trailing: 51))
    let wider = PageAxisInsets(content: 800, bounds: 402, fitLeading: 0, fitTrailing: 0)
    #expect(wider == PageAxisInsets(leading: 0, trailing: 0))
}
