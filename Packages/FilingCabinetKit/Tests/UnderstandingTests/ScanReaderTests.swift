import CoreGraphics
import TestSupport
import Testing
import Understanding

private func text(_ lines: String..., top: String? = nil) -> PageText {
    var out = lines.enumerated().map {
        TextLine(text: $1, box: CGRect(x: 0.1, y: 0.5 + Double($0) * 0.05, width: 0.5, height: 0.02))
    }
    if let top { out.insert(TextLine(text: top, box: CGRect(x: 0.1, y: 0.05, width: 0.5, height: 0.05)), at: 0) }
    return PageText(lines: out)
}

/// Copy Text copies it as stored: each page's lines, and a blank line between pages (M11).
@Test func joinsSearchTextInPageOrder() async {
    let fake = FakeTextReader([.page(text("a", "b")), .page(text("c"))])
    let pages = [SyntheticPages.blank(), SyntheticPages.blank()]

    let reading = await ScanReader(reader: fake).read(pages)

    #expect(reading.searchText == "a\nb\n\nc")
    #expect(reading.failedPages == 0)
}

@Test func failedPageIsCountedAndSkipped() async {
    let fake = FakeTextReader([.page(text("a")), .failure(.recognitionFailed), .page(text("c"))])
    let pages = [SyntheticPages.blank(), SyntheticPages.blank(), SyntheticPages.blank()]

    let reading = await ScanReader(reader: fake).read(pages)

    #expect(reading.searchText == "a\n\nc")
    #expect(reading.failedPages == 1)
}

@Test func titleComesFromPageOne() async {
    let fake = FakeTextReader([
        .page(text("body", top: "CITY PHARMACY")),
        .page(text("x", top: "Other Page")),
    ])
    let pages = [SyntheticPages.blank(), SyntheticPages.blank()]

    let reading = await ScanReader(reader: fake).read(pages)

    #expect(reading.title == "City Pharmacy")
}

@Test func noPagesReadsNothing() async {
    let reading = await ScanReader(reader: FakeTextReader([])).read([])

    #expect(reading == ScanReading(title: nil, searchText: "", failedPages: 0))
}

@Test func titleIsNilWhenPageOneFails() async {
    let fake = FakeTextReader([.failure(.recognitionFailed), .page(text("x", top: "Other Page"))])
    let pages = [SyntheticPages.blank(), SyntheticPages.blank()]

    let reading = await ScanReader(reader: fake).read(pages)

    #expect(reading.title == nil)
    #expect(reading.searchText == "Other Page\nx")
    #expect(reading.failedPages == 1)
}

// The wait for the first read is a busy loop: the limit turns a reader that never starts into a failure, not a hang.
@Test(.timeLimit(.minutes(1)))
func cancellingStopsReadingLaterPages() async {
    let fake = FakeTextReader([.page(text("a"), delay: .seconds(5)), .page(text("b"))])
    let pages = [SyntheticPages.blank(), SyntheticPages.blank(), SyntheticPages.blank()]
    let reader = ScanReader(reader: fake)

    let task = Task { await reader.read(pages) }
    while fake.readCount == 0 { await Task.yield() }
    task.cancel()
    let reading = await task.value

    #expect(fake.readCount == 1)
    #expect(reading.failedPages == 0)
}
