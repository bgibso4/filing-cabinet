/// Everything a reader found on one page, in Vision's reading order.
public struct PageText: Sendable, Equatable {
    package let lines: [TextLine]

    package init(lines: [TextLine]) {
        self.lines = lines
    }
}
