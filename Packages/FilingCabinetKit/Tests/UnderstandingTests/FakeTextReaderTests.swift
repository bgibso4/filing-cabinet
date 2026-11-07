import CoreGraphics
import TestSupport
import Testing

@testable import Understanding

private let one = PageText(lines: [TextLine(text: "one", box: .zero)])
private let two = PageText(lines: [TextLine(text: "two", box: .zero)])

@Test func fakeAnswersInScriptOrderThenRepeatsTheLastStep() async throws {
    let fake = FakeTextReader([.page(one), .page(two)])
    let page = SyntheticPages.blank()

    #expect(try await fake.read(page) == one)
    #expect(try await fake.read(page) == two)
    #expect(try await fake.read(page) == two)
    #expect(fake.readCount == 3)
}

@Test func fakeThrowsAScriptedFailure() async {
    let fake = FakeTextReader([.failure(.recognitionFailed)])

    await #expect(throws: UnderstandingError.recognitionFailed) {
        try await fake.read(SyntheticPages.blank())
    }
}

@Test func fakeWithAnEmptyScriptReadsNoLines() async throws {
    #expect(try await FakeTextReader([]).read(SyntheticPages.blank()).lines.isEmpty)
}

@Test func fakeReadsCityPharmacyFirst() async throws {
    let text = try await FakeTextReader.readsCityPharmacy().read(SyntheticPages.blank())

    #expect(text.lines.first?.text == "CITY PHARMACY")
}

@Test func syntheticPageHasTheRequestedSize() {
    let page = SyntheticPages.page(lines: [("Hi", 40)], size: CGSize(width: 300, height: 200))

    #expect(page.width == 300)
    #expect(page.height == 200)
}
