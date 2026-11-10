import Core
import Foundation
import Library
import Testing

@testable import ScreenModels
@testable import TestSupport

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
    return calendar
}()

private let oct12 = CalendarDay(year: 2026, month: 10, day: 12)
private let noon = oct12.date(in: utc).addingTimeInterval(12 * 3600)
private let clock = AppClock.fixed(noon, calendar: utc)

/// A scan with its text, scanned `daysAgo` days before Oct 12; in Trash since today when `trashed`.
private struct Seed {
    let scan: ScanSummary
    let text: String

    init(
        _ title: String,
        _ collection: BuiltInCollection = .documents,
        text: String = "",
        daysAgo: Int = 0,
        trashed: Bool = false
    ) {
        scan = ScanSummary(
            id: ScanID(),
            title: title,
            collection: collection,
            scannedAt: noon.addingTimeInterval(Double(-daysAgo) * 86_400),
            expiryOverride: nil,
            pageCount: 1,
            trashedDay: trashed ? oct12 : nil)
        self.text = text
    }

    var id: ScanID { scan.id }
}

/// A Search model over a fake library holding `seeds`, with its own history.
@MainActor
private struct Fixture {
    let library: FakeLibrary
    let history: SearchHistory
    let analytics = RecordingAnalytics()
    let model: SearchModel
    private let fresh: FreshDefaults

    init(_ seeds: [Seed]) throws {
        fresh = try FreshDefaults()
        library = FakeLibrary(scans: seeds.map(\.scan), clock: clock)
        for seed in seeds { library.updateSearchText(seed.text, for: seed.id) }
        history = SearchHistory(defaults: fresh.defaults)
        model = SearchModel(
            library: library, today: Today(clock: clock), clock: clock, history: history, analytics: analytics)
    }

    func cleanUp() { fresh.cleanUp() }

    func search(_ query: String, in filter: BuiltInCollection? = nil) -> [ScanID] {
        model.query = query
        model.filter = filter
        return model.results.map(\.id)
    }
}

@MainActor
@Test func titleMatchesComeFirst() throws {
    let inText = Seed("Lease 2026", text: "Re: Lease renewal")
    let inTitle = Seed("Renewal notice", daysAgo: 5)
    let fixture = try Fixture([inText, inTitle])
    defer { fixture.cleanUp() }
    #expect(fixture.search("renew") == [inTitle.id, inText.id])
}

@MainActor
@Test func newestFirstWithinEach() throws {
    let olderTitle = Seed("Renew car", daysAgo: 9)
    let newerTitle = Seed("Renew gym", daysAgo: 1)
    let olderText = Seed("Lease", text: "renewal", daysAgo: 8)
    let newerText = Seed("Card", text: "Renews monthly", daysAgo: 2)
    let fixture = try Fixture([olderTitle, olderText, newerText, newerTitle])
    defer { fixture.cleanUp() }
    #expect(fixture.search("renew") == [newerTitle.id, olderTitle.id, newerText.id, olderText.id])
}

@MainActor
@Test func neverSearchesTrash() throws {
    let kept = Seed("Bike lock", .receipts)
    let trashed = Seed("Bike pump", .receipts, text: "bike", trashed: true)
    let fixture = try Fixture([kept, trashed])
    defer { fixture.cleanUp() }
    #expect(fixture.search("bike") == [kept.id])
}

@MainActor
@Test func filterLimitsResults() throws {
    let card = Seed("Gym membership", .wallet, text: "Plan · Renews monthly")
    let lease = Seed("Lease 2026", .documents, text: "Re: Lease renewal")
    let fixture = try Fixture([card, lease])
    defer { fixture.cleanUp() }
    #expect(fixture.search("renew", in: .wallet) == [card.id])
    fixture.model.searchAll()
    #expect(fixture.model.filter == nil)
    #expect(fixture.model.results.map(\.id) == [card.id, lease.id])
}

@MainActor
@Test func resultReadsItsSnippetAndPlace() throws {
    let lease = Seed("Lease 2026", .documents, text: "Harbor\nRe: Lease renewal", daysAgo: 11)
    let old = Seed("Lease 2025", .documents, text: "renewal", daysAgo: 400)
    let fixture = try Fixture([lease, old])
    defer { fixture.cleanUp() }
    fixture.model.query = "renew"
    let result = try #require(fixture.model.results.first)
    #expect(result.title == "Lease 2026")
    #expect(result.snippet == "Re: Lease renewal")
    #expect(result.bold.map { String(result.snippet[$0]) } == ["renew"])
    #expect(result.collection == .documents)
    #expect(result.detail == "Documents · Oct 1")
    #expect(fixture.model.results.last?.detail == "Documents · Sep 7, 2025")
}

@MainActor
@Test func headerCopy() throws {
    let fixture = try Fixture([
        Seed("Bike lock", .wallet), Seed("Bike shop", .wallet), Seed("Bike pump", .receipts),
    ])
    defer { fixture.cleanUp() }
    _ = fixture.search("bike")
    #expect(fixture.model.header == "3 scans")
    _ = fixture.search("pump")
    #expect(fixture.model.header == "1 scan")
    _ = fixture.search("bike", in: .wallet)
    #expect(fixture.model.header == "2 scans in Wallet")
    _ = fixture.search("lock", in: .wallet)
    #expect(fixture.model.header == "1 scan in Wallet")
}

@MainActor
@Test func nothingHereNamesWhereElse() throws {
    let fixture = try Fixture([
        Seed("Ride", .notes, text: "bike"), Seed("Bike", .receipts), Seed("Bike shop", .notes), Seed("Card", .wallet),
    ])
    defer { fixture.cleanUp() }
    _ = fixture.search("ride", in: .wallet)
    #expect(
        fixture.model.state == .nothingHere(title: "No results in Wallet", body: "1 scan in Notes mentions “ride”."))
    _ = fixture.search("ride", in: .receipts)
    #expect(
        fixture.model.state == .nothingHere(title: "No results in Receipts", body: "1 scan in Notes mentions “ride”."))
    // Two collections: the one with more first, so Notes (2) before Receipts (1).
    _ = fixture.search("bike", in: .wallet)
    #expect(
        fixture.model.state
            == .nothingHere(title: "No results in Wallet", body: "3 scans in Notes and Receipts mention “bike”."))
}

@MainActor
@Test func nothingHereAcrossThreeCollections() throws {
    let fixture = try Fixture([
        Seed("Bike", .receipts), Seed("Bike shop", .notes), Seed("Bike", .documents), Seed("Bike", .throwaways),
        Seed("Card", .wallet),
    ])
    defer { fixture.cleanUp() }
    _ = fixture.search("bike", in: .wallet)
    #expect(
        fixture.model.state
            == .nothingHere(title: "No results in Wallet", body: "4 scans in other collections mention “bike”."))
}

@MainActor
@Test func nothingAnywhereCopy() throws {
    let fixture = try Fixture([Seed("Lease 2026", text: "renewal")])
    defer { fixture.cleanUp() }
    let body = "Search reads the words on every scan. Check the spelling or try another word."
    _ = fixture.search(" renwal ")
    #expect(fixture.model.state == .nothingAnywhere(title: "No results for “renwal”", body: body))
    _ = fixture.search("renwal", in: .wallet)
    #expect(fixture.model.state == .nothingAnywhere(title: "No results for “renwal”", body: body))
}

@MainActor
@Test func firstUseShowsOnlyFilters() throws {
    let fixture = try Fixture([Seed("Lease 2026")])
    defer { fixture.cleanUp() }
    #expect(fixture.model.state == .firstUse)
    fixture.model.query = "   "
    #expect(fixture.model.state == .firstUse)
}

@MainActor
@Test func beforeTypingShowsFourViewedStillInLibrary() throws {
    let seeds = (1...6).map { Seed("Scan \($0)", .notes) }
    let trashed = Seed("Old", trashed: true)
    let fixture = try Fixture(seeds + [trashed])
    defer { fixture.cleanUp() }
    for seed in seeds { fixture.history.record(viewed: seed.id) }
    fixture.history.record(viewed: trashed.id)
    fixture.history.record(viewed: ScanID())
    fixture.history.record(search: "wifi")
    let viewed = (2...5).reversed().map { SearchViewed(id: seeds[$0].id, title: "Scan \($0 + 1)", collection: .notes) }
    #expect(fixture.model.state == .beforeTyping(viewed: viewed, searches: ["wifi"]))
}

@MainActor
@Test func submitSavesTheSearch() throws {
    let fixture = try Fixture([Seed("Bike lock"), Seed("Bike pump")])
    defer { fixture.cleanUp() }
    fixture.model.query = "  "
    fixture.model.submit()
    #expect(fixture.history.recentSearches.isEmpty)
    #expect(fixture.analytics.events.isEmpty)
    fixture.model.query = " bike "
    fixture.model.submit()
    #expect(fixture.history.recentSearches == ["bike"])
    #expect(fixture.analytics.events == [.searchSaved(resultCount: 2)])
}

@MainActor
@Test func openingAResultSavesIt() throws {
    let lock = Seed("Bike lock", .wallet)
    let fixture = try Fixture([lock, Seed("Bike pump")])
    defer { fixture.cleanUp() }
    _ = fixture.search("bike", in: .wallet)
    fixture.model.opened(lock.id)
    #expect(fixture.history.recentSearches == ["bike"])
    #expect(fixture.analytics.events == [.searchSaved(resultCount: 1)])
}

@MainActor
@Test func noAnalyticsCarriesText() throws {
    let lock = Seed("Bike lock", text: "Hauptstraße")
    let fixture = try Fixture([lock])
    defer { fixture.cleanUp() }
    _ = fixture.search("straße bike")
    fixture.model.submit()
    fixture.model.opened(lock.id)
    #expect(fixture.analytics.events.count == 2)
    for event in fixture.analytics.events {
        let described = "\(event.name) \(event.payload)"
        for word in ["straße", "bike", "Bike lock", "Hauptstraße"] { #expect(!described.contains(word)) }
    }
}

@MainActor
@Test func editsAreSearchedAgain() async throws {
    let lease = Seed("Lease 2026", text: "Unit 4B")
    let fixture = try Fixture([lease])
    defer { fixture.cleanUp() }
    #expect(fixture.search("harbor").isEmpty)
    try fixture.library.rename(lease.id, to: "Harbor lease")
    #expect(fixture.search("harbor") == [lease.id])
    let new = ScanDraft(
        id: ScanID(),
        title: "Note",
        collection: .notes,
        scannedAt: noon.addingTimeInterval(-86_400),
        expiryOverride: nil,
        pages: [],
        searchText: "harbor view")
    try await fixture.library.save(new)
    #expect(fixture.search("harbor") == [lease.id, new.id])
    fixture.library.updateSearchText("Unit 4B", for: new.id)
    try fixture.library.rename(lease.id, to: "Harbor lease 2026")
    #expect(fixture.search("harbor") == [lease.id])
    try fixture.library.moveToTrash([lease.id])
    #expect(fixture.search("harbor").isEmpty)
}
