#if canImport(UIKit)
    import Testing
    import UIKit

    @testable import Screens

    @MainActor
    struct DetailsSwipeTests {
        /// One finger only: a pinch on an unzoomed page, its centre drifting upward, zooms rather than opening Details.
        @Test func aPinchNeverSwipes() {
            #expect(DetailsSwipe.makePan().maximumNumberOfTouches == 1)
        }
    }
#endif
