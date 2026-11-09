import CoreGraphics
import Testing

@testable import ScreenModels

@Test func pageFitFollowsProgress() {
    #expect(DetailsMotion.pageFitBottom(progress: 0, closed: 130, open: 260) == 130)
    #expect(DetailsMotion.pageFitBottom(progress: 0.5, closed: 130, open: 260) == 195)
    #expect(DetailsMotion.pageFitBottom(progress: 1, closed: 130, open: 260) == 260)
    #expect(DetailsMotion.pageFitBottom(progress: 1.4, closed: 130, open: 260) == 260)
    #expect(DetailsMotion.pageFitBottom(progress: -0.4, closed: 130, open: 260) == 130)
}

@Test func chromeFadesWithProgress() {
    #expect(DetailsMotion.chromeOpacity(progress: 0) == 1)
    #expect(DetailsMotion.chromeOpacity(progress: 0.25) == 0.75)
    #expect(DetailsMotion.chromeOpacity(progress: 1) == 0)
    #expect(DetailsMotion.chromeOpacity(progress: 1.5) == 0)
    #expect(DetailsMotion.chromeOpacity(progress: -0.5) == 1)
}

@Test func panelOffsetShrinksAsItOpens() {
    #expect(DetailsMotion.panelOffset(progress: 0, travel: 214) == 214)
    #expect(DetailsMotion.panelOffset(progress: 0.5, travel: 214) == 107)
    #expect(DetailsMotion.panelOffset(progress: 1, travel: 214) == 0)
}

@Test func dragUpRaisesProgress() {
    #expect(DetailsMotion.progress(dragStart: 0, translation: -107, travel: 214) == 0.5)
    #expect(DetailsMotion.progress(dragStart: 0, translation: -500, travel: 214) == 1)
    #expect(DetailsMotion.progress(dragStart: 0, translation: 50, travel: 214) == 0)
    #expect(DetailsMotion.progress(dragStart: 1, translation: 107, travel: 214) == 0.5)
}

@Test func halfwayDecidesAtRest() {
    #expect(DetailsMotion.target(progress: 0.49, velocity: 0) == 0)
    #expect(DetailsMotion.target(progress: 0.5, velocity: 0) == 1)
}

@Test func flickBeatsHalfway() {
    #expect(DetailsMotion.target(progress: 0.2, velocity: 0.7) == 1)
    #expect(DetailsMotion.target(progress: 0.8, velocity: -0.7) == 0)
    #expect(DetailsMotion.target(progress: 0.2, velocity: 0.6) == 1)
    #expect(DetailsMotion.target(progress: 0.2, velocity: 0.59) == 0)
}

@Test func springSettlesOnTarget() {
    var spring = DetailsSpring(position: 0, velocity: 0, target: 1)
    var peak: CGFloat = 0
    var seconds = 0.0
    while !spring.isSettled && seconds < 1 {
        spring.step(by: 1.0 / 60)
        seconds += 1.0 / 60
        peak = max(peak, spring.position)
    }
    #expect(spring.isSettled)
    #expect(spring.position == 1)
    #expect(spring.velocity == 0)
    #expect(peak <= 1.02)
}

@Test func retargetingKeepsPositionAndVelocity() {
    var spring = DetailsSpring(position: 0, velocity: 0, target: 1)
    for _ in 0..<6 { spring.step(by: 1.0 / 60) }
    let (position, velocity) = (spring.position, spring.velocity)
    #expect(position > 0 && velocity > 0)
    spring.target = 0
    #expect(spring.position == position)
    #expect(spring.velocity == velocity)
    var steps = 0
    while !spring.isSettled && steps < 600 {
        spring.step(by: 1.0 / 60)
        steps += 1
    }
    #expect(spring.position == 0)
}

@Test func largeStepsAreCapped() {
    var big = DetailsSpring(position: 0, velocity: 0, target: 1)
    var capped = big
    big.step(by: 1)
    capped.step(by: 1.0 / 30)
    #expect(big == capped)
}

@Test func zoomedPageNeverOpensDetails() {
    let swipeUp = CGSize(width: 0, height: -40)
    #expect(DetailsMotion.swipeOpens(translation: swipeUp, isPageZoomed: false, isFromTrash: false))
    #expect(!DetailsMotion.swipeOpens(translation: swipeUp, isPageZoomed: true, isFromTrash: false))
    #expect(!DetailsMotion.swipeOpens(translation: swipeUp, isPageZoomed: false, isFromTrash: true))
    #expect(
        !DetailsMotion.swipeOpens(translation: CGSize(width: 40, height: -10), isPageZoomed: false, isFromTrash: false))
    #expect(
        !DetailsMotion.swipeOpens(translation: CGSize(width: 0, height: 40), isPageZoomed: false, isFromTrash: false))
}
