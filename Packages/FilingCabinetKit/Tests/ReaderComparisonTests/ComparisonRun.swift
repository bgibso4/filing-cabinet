import Core
import Understanding

/// What one reader found on every fixture, in fixture order.
struct ComparisonRun {
    let kind: ReaderKind
    /// The reader's first read in this process (page 1 of the first fixture).
    let coldMilliseconds: Double
    let readings: [ScanReading]
    let msPerPage: [Double]

    var failedPages: Int {
        readings.reduce(0) { $0 + $1.failedPages }
    }
}
