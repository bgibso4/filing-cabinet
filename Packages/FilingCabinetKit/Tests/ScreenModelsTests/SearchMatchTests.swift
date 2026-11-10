import Testing

@testable import ScreenModels

/// Matches `query` against a scan the way Search does: everything folded once, then matched.
private func hit(_ query: String, title: String, text: String = "") -> SearchHit? {
    SearchMatch.match(
        title: SearchMatch.Folded(title),
        text: SearchMatch.Folded(text),
        terms: SearchMatch.terms(query).map(SearchMatch.Folded.init))
}

/// The bold parts of the hit's snippet, in order.
private func bold(_ hit: SearchHit?) -> [String] {
    guard let hit else { return [] }
    return hit.bold.map { String(hit.snippet[$0]) }
}

@Test func termsSplitOnWhitespaceAndDropEmpties() {
    #expect(SearchMatch.terms("  renew \n lease\t") == ["renew", "lease"])
    #expect(SearchMatch.terms("   ").isEmpty)
}

@Test func everyWordMustMatch() {
    #expect(hit("lease unit", title: "Lease 2026", text: "Unit 4B") != nil)
    #expect(hit("lease bike", title: "Lease 2026", text: "Unit 4B") == nil)
}

@Test func matchesInsideWords() {
    #expect(bold(hit("renew", title: "Call with landlord", text: "renewal: sign by Nov 15")) == ["renew"])
    #expect(bold(hit("renew", title: "Gym membership", text: "Plan · Renews monthly")) == ["Renew"])
}

@Test func ignoresCaseAndAccents() {
    #expect(hit("cafe", title: "Café Lumière") != nil)
    #expect(bold(hit("CAFE", title: "Receipt", text: "Café Lumière")) == ["Café"])
    #expect(bold(hit("café", title: "Receipt", text: "CAFE LUMIERE")) == ["CAFE"])
}

/// Folding turns ß into "ss" (checked: `"Straße".folding(…)` is "strasse"), so the folded bytes match, and the
/// original line's compare finds the whole word.
@Test func foldsSharpS() {
    let found = hit("strasse", title: "Letter", text: "Hauptstraße 5")
    #expect(found != nil)
    #expect(bold(found) == ["straße"])
    #expect(hit("Straße", title: "Letter", text: "HAUPTSTRASSE 5") != nil)
}

@Test func multiWordAcrossTitleAndText() {
    let found = hit("lease renew", title: "Lease 2026", text: "Re: Lease renewal · Unit 4B")
    #expect(found?.titleMatches == false)
    #expect(bold(found) == ["Lease", "renew"])
    #expect(hit("lease 2026", title: "Lease 2026", text: "Unit 4B")?.titleMatches == true)
}

@Test func snippetIsTheFirstMatchingLine() {
    let text = "Harbor Property Management\n\n  Re: Lease renewal · Unit 4B · term  \nRenew by Nov 1"
    let found = hit("renew", title: "Lease 2026", text: text)
    #expect(found?.snippet == "Re: Lease renewal · Unit 4B · term")
}

@Test func everyMatchIsBold() {
    let found = hit("renew plan", title: "Gym", text: "Plan · Renews monthly · renew online · plan B")
    #expect(bold(found) == ["Plan", "Renew", "renew", "plan"])
}

@Test func titleOnlyMatchShowsFirstLineUnbolded() {
    let found = hit("lease", title: "Lease 2026", text: "\nHarbor Property Management\nUnit 4B")
    #expect(found?.titleMatches == true)
    #expect(found?.snippet == "Harbor Property Management")
    #expect(found?.bold.isEmpty == true)
}

@Test func emptyTextStillMatchesByTitle() {
    let found = hit("lease", title: "Lease 2026", text: "")
    #expect(found?.titleMatches == true)
    #expect(found?.snippet.isEmpty == true)
    #expect(hit("unit", title: "Lease 2026", text: "") == nil)
}

@Test func noTermsMatchNothing() {
    #expect(hit("  ", title: "Lease 2026", text: "Unit 4B") == nil)
}
