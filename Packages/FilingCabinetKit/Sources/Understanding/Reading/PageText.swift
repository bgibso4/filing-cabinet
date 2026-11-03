/// Everything a reader found on one page, in Vision's reading order.
public struct PageText: Sendable, Equatable {
    public let lines: [TextLine]

    public init(lines: [TextLine]) {
        self.lines = lines
    }
}
