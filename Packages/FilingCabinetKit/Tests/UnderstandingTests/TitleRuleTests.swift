import CoreGraphics
import Testing

@testable import Understanding

private func line(_ text: String, top: Double, height: Double) -> TextLine {
    TextLine(text: text, box: CGRect(x: 0.1, y: top, width: 0.5, height: height))
}

private func page(_ lines: TextLine...) -> PageText { PageText(lines: lines) }

@Test func tallestLineInTheTopWins() {
    let first = page(
        line("Receipt #4471", top: 0.05, height: 0.03),
        line("City Pharmacy", top: 0.10, height: 0.06),
        line("THANK YOU", top: 0.8, height: 0.09))

    #expect(TitleRule.title(from: [first]) == "City Pharmacy")
}

@Test func allCapsIsTitleCased() {
    #expect(TitleRule.title(from: [page(line("CITY PHARMACY", top: 0.1, height: 0.05))]) == "City Pharmacy")
    #expect(TitleRule.title(from: [page(line("Bio 210 · Oct 10", top: 0.1, height: 0.05))]) == "Bio 210 · Oct 10")
}

@Test func wordsWithDigitsKeepTheirCase() {
    #expect(
        TitleRule.title(from: [page(line("LEASE RENEWAL UNIT 4B", top: 0.1, height: 0.05))]) == "Lease Renewal Unit 4B")
}

@Test func tieGoesToTheHigherLine() {
    let tied = page(
        line("Lower Line", top: 0.20, height: 0.05),
        line("Upper Line", top: 0.10, height: 0.05))

    #expect(TitleRule.title(from: [tied]) == "Upper Line")
}

@Test func linesWithFewerThanThreeLettersAreSkipped() {
    let skipped = page(
        line("00.00", top: 0.05, height: 0.09),
        line("#4", top: 0.06, height: 0.09),
        line("Rent", top: 0.15, height: 0.02))

    #expect(TitleRule.title(from: [skipped]) == "Rent")
}

@Test func linesBelowTheTopFortyPercentAreIgnored() {
    #expect(TitleRule.title(from: [page(line("Footer Note", top: 0.6, height: 0.09))]) == nil)
}

@Test func onlyPageOneCounts() {
    let one = page(line("Page One", top: 0.1, height: 0.02))
    let two = page(line("Page Two", top: 0.1, height: 0.09))

    #expect(TitleRule.title(from: [one, two]) == "Page One")
    #expect(TitleRule.title(from: [PageText(lines: []), two]) == nil)
}

@Test func nothingReadableIsNil() {
    #expect(TitleRule.title(from: []) == nil)
    #expect(TitleRule.title(from: [PageText(lines: [])]) == nil)
}

@Test func longTitleIsCutTo60() {
    let long = String(repeating: "Word ", count: 20)
    let title = TitleRule.title(from: [page(line(long, top: 0.1, height: 0.05))])

    #expect(title?.count == 59)
    #expect(title?.hasPrefix("Word Word") == true)
    let exact = String(repeating: "a", count: 80)
    #expect(TitleRule.title(from: [page(line(exact, top: 0.1, height: 0.05))])?.count == 60)
}

@Test func whitespaceIsCollapsed() {
    #expect(TitleRule.title(from: [page(line("  City \t  Pharmacy \n", top: 0.1, height: 0.05))]) == "City Pharmacy")
}
