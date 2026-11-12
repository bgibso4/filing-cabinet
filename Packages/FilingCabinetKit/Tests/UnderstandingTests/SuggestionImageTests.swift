import CoreGraphics
import TestSupport
import Testing

@testable import Understanding

@Test func largePageIsFittedToTheLongSide() throws {
    let page = SyntheticPages.page(lines: [], size: CGSize(width: 2_480, height: 3_508))

    let small = try #require(SuggestionImage.fitted(page, longSide: 1_024))

    #expect(small.height == 1_024)
    #expect(small.width == 724)
}

@Test func smallPageIsLeftAsIs() throws {
    let page = SyntheticPages.page(lines: [], size: CGSize(width: 300, height: 200))

    #expect(SuggestionImage.fitted(page, longSide: 1_024) === page)
}
