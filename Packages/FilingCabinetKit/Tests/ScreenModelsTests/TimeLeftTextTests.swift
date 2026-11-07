import Core
import Testing

@testable import ScreenModels

@Test(
    arguments: [
        (TimeLeft.days(1), "1 day left"), (.days(59), "59 days left"), (.days(60), "2 months left"),
        (.days(364), "12 months left"), (.days(365), "1 year left"), (.days(730), "2 years left"),
        (.forever, "Kept forever"),
        // Expired scans are hidden; if one is ever reached it must not claim permanence.
        (.expired, "0 days left"),
    ])
func timeLeftBoundaries(left: TimeLeft, expected: String) {
    #expect(TimeLeftText.text(left) == expected)
}
