import Testing

@testable import ScreenModels

@Test func forwardWindowIsTheNextThirtySixPastTheLastVisible() {
    let window = GridPrefetchWindow.indexes(visible: 0...11, direction: .forward, total: 2_000)
    #expect(window == Array(12..<48))
}

@Test func forwardWindowStopsAtTheEndOfTheList() {
    #expect(GridPrefetchWindow.indexes(visible: 80...91, direction: .forward, total: 100) == Array(92..<100))
    #expect(GridPrefetchWindow.indexes(visible: 88...99, direction: .forward, total: 100).isEmpty)
}

@Test func backwardWindowIsNearestFirstAndStopsAtTheTop() {
    let window = GridPrefetchWindow.indexes(visible: 100...111, direction: .backward, total: 2_000)
    #expect(window == Array((64..<100).reversed()))
    #expect(GridPrefetchWindow.indexes(visible: 3...14, direction: .backward, total: 100) == [2, 1, 0])
    #expect(GridPrefetchWindow.indexes(visible: 0...11, direction: .backward, total: 100).isEmpty)
}

@Test func directionFollowsTheEdgeThatGrew() {
    typealias Window = GridPrefetchWindow
    #expect(Window.direction(from: 0...11, to: 0...14, current: .backward) == .forward)
    #expect(Window.direction(from: 50...61, to: 49...61, current: .forward) == .backward)
    // A tile leaving says nothing new.
    #expect(Window.direction(from: 0...14, to: 3...14, current: .forward) == .forward)
    #expect(Window.direction(from: 3...14, to: 3...11, current: .backward) == .backward)
    #expect(Window.direction(from: nil, to: 0...11, current: .forward) == .forward)
}
