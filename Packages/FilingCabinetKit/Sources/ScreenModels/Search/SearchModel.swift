import Core
import Foundation
import Library
import Observation

/// What Search shows (08-01…08-06): before typing, the recently viewed scans and recent searches; then the library's
/// scans holding every word, title matches first (M15), in All or one collection. Trash and expired scans are never
/// searched. Each scan's title and text are folded once, when the model is made, and again only for the scans that
/// change (E3): an edit, a new scan, Trash, or a text that finishes reading while Search is open.
@MainActor
@Observable
package final class SearchModel {
    /// Which of 08-01…08-06 shows.
    package enum State: Equatable {
        /// Nothing viewed or searched yet: only the filters (08-01).
        case firstUse
        /// Up to 4 recently viewed scans still in the library, and the recent searches (08-02).
        case beforeTyping(viewed: [SearchViewed], searches: [String])
        /// `results` and `header` (08-03, 08-04).
        case results
        /// Nothing in the filter's collection, though other collections have some (08-05).
        case nothingHere(title: String, body: String)
        /// Nothing anywhere (08-06).
        case nothingAnywhere(title: String, body: String)
    }

    /// One library scan, folded for matching.
    private struct Entry {
        let scan: ScanSummary
        let title: SearchMatch.Folded
        let text: SearchMatch.FoldedText
    }

    /// A query's matches in every collection, newest first, and the scans they were found among.
    private struct LastSearch {
        let query: String
        let scans: [ScanSummary]
        let hits: [(Entry, SearchHit)]
    }

    /// The library scans with their folds, and what they were built from.
    private struct Index {
        let scans: [ScanSummary]
        let lifespans: CollectionLifespans
        let day: CalendarDay
        let textRevision: Int
        /// Newest first.
        let entries: [Entry]
    }

    /// One scan's match against the folded terms.
    package typealias Matching = (SearchMatch.Folded, SearchMatch.FoldedText, [SearchMatch.Folded]) -> SearchHit?

    /// The field's text, as typed.
    package var query = ""
    /// The chip: nil is All.
    package var filter: BuiltInCollection?

    private let library: any ScanLibrary
    private let today: Today
    private let clock: AppClock
    private let history: SearchHistory
    @ObservationIgnored private let analytics: any Analytics
    /// How one scan is matched: `SearchMatch.match`, unless a test counts the visits.
    @ObservationIgnored private let matching: Matching
    @ObservationIgnored private var index: Index?
    /// The last query's matches in every collection, and the scans they came from.
    @ObservationIgnored private var lastSearch: LastSearch?
    /// The search last kept, so keeping it again (Search, then opening a result) reports it once (M19).
    @ObservationIgnored private var lastSaved: String?
    /// Each shown result's third line, made once per index: formatting a date per result per keystroke adds up.
    @ObservationIgnored private var details: [ScanID: String] = [:]

    package init(
        library: any ScanLibrary,
        today: Today,
        clock: AppClock,
        history: SearchHistory,
        analytics: any Analytics,
        matching: @escaping Matching = { SearchMatch.match(title: $0, text: $1, terms: $2) }
    ) {
        self.matching = matching
        self.library = library
        self.today = today
        self.clock = clock
        self.history = history
        self.analytics = analytics
        index = makeIndex()
    }

    package var state: State {
        guard !terms.isEmpty else {
            let viewed = viewed
            let searches = history.recentSearches
            return viewed.isEmpty && searches.isEmpty ? .firstUse : .beforeTyping(viewed: viewed, searches: searches)
        }
        if !shown.isEmpty { return .results }
        let quoted = terms.joined(separator: " ")
        let elsewhere = hits.map(\.0.scan.collection)
        if let filter, !elsewhere.isEmpty {
            return .nothingHere(
                title: String(localized: "No results in \(CollectionText.name(filter))", bundle: #bundle),
                body: Self.elsewhereLine(elsewhere, query: quoted))
        }
        return .nothingAnywhere(
            title: String(localized: "No results for “\(quoted)”", bundle: #bundle),
            body: String(
                localized: "Search reads the words on every scan. Check the spelling or try another word.",
                bundle: #bundle))
    }

    /// The matches in the filter's collection, as rows.
    package var results: [SearchResult] {
        let day = today.day
        return shown.map { entry, hit in
            SearchResult(
                id: entry.scan.id,
                title: entry.scan.title,
                snippet: hit.snippet,
                bold: hit.bold,
                collection: entry.scan.collection,
                detail: detail(entry.scan, today: day))
        }
    }

    /// "5 scans", "1 scan", or with a filter "2 scans in Wallet" (M17).
    package var header: String {
        let count = shown.count
        guard let filter else { return String(localized: "\(count) scans", bundle: #bundle) }
        return String(localized: "\(count) scans in \(CollectionText.name(filter))", bundle: #bundle)
    }

    /// 08-05's Search all scans: picks All.
    package func searchAll() {
        filter = nil
    }

    /// Recent searches' Clear (08-02): empties them, so the next search is kept and reported afresh.
    package func clearSearches() {
        history.clearSearches()
        lastSaved = nil
    }

    /// The keyboard's Search: keeps the search (M5).
    package func submit() {
        save()
    }

    /// A result was opened: keeps the search (M5). The viewer records the scan as viewed.
    package func opened(_: ScanID) {
        save()
    }

    // MARK: Private

    // M4: Search shows the first 4 recently viewed scans still in the library.
    private static let viewedShown = 4

    private var terms: [String] { SearchMatch.terms(query) }

    /// The matches in the filter's collection, title matches first, each group newest first (M15).
    private var shown: [(Entry, SearchHit)] {
        let hits = hits.filter { filter == nil || $0.0.scan.collection == filter }
        return hits.filter(\.1.titleMatches) + hits.filter { !$0.1.titleMatches }
    }

    private var viewed: [SearchViewed] {
        let visible = Dictionary(uniqueKeysWithValues: currentIndex.entries.map { ($0.scan.id, $0.scan) })
        return history.recentlyViewed.compactMap { visible[$0] }.prefix(Self.viewedShown).map {
            SearchViewed(id: $0.id, title: $0.title, collection: $0.collection)
        }
    }

    /// The query's matches in every collection, newest first. Matched again only when the query or the scans change.
    private var hits: [(Entry, SearchHit)] {
        let index = currentIndex
        if let lastSearch, lastSearch.query == query, lastSearch.scans == index.scans { return lastSearch.hits }
        let terms = terms.map(SearchMatch.Folded.init)
        let interval = ScreenModelsLog.signposter.beginInterval(
            "Search", id: ScreenModelsLog.signposter.makeSignpostID())
        let hits = index.entries.compactMap { entry in
            matching(entry.title, entry.text, terms).map { (entry, $0) }
        }
        ScreenModelsLog.signposter.endInterval("Search", interval)
        lastSearch = LastSearch(query: query, scans: index.scans, hits: hits)
        return hits
    }

    /// The index, rebuilt when the scans, lifespans or day change. Reading them here is what makes the views follow.
    private var currentIndex: Index {
        if let index, index.scans == library.scans, index.lifespans == library.lifespans, index.day == today.day,
            index.textRevision == library.searchTextRevision
        {
            return index
        }
        let rebuilt = makeIndex()
        index = rebuilt
        lastSearch = nil
        details = [:]
        return rebuilt
    }

    /// Reads every text in one fetch, and folds only the titles and texts that differ from the last index's.
    private func makeIndex() -> Index {
        let scans = library.scans
        let lifespans = library.lifespans
        let day = today.day
        let textRevision = library.searchTextRevision
        let visible = LibraryShelf(scans: scans, lifespans: lifespans, today: day, calendar: clock.calendar).visible
        let texts = library.searchTexts()
        let previous = Dictionary(uniqueKeysWithValues: (index?.entries ?? []).map { ($0.scan.id, $0) })
        let entries = visible.map { scan in
            let text = texts[scan.id] ?? ""
            let old = previous[scan.id]
            return Entry(
                scan: scan,
                title: old.flatMap { $0.title.original == scan.title ? $0.title : nil } ?? .init(scan.title),
                text: old.flatMap { $0.text.original == text ? $0.text : nil } ?? .init(text))
        }
        return Index(scans: scans, lifespans: lifespans, day: day, textRevision: textRevision, entries: entries)
    }

    /// "Documents · Oct 1", with the year when it isn't this one (M16).
    private func detail(_ scan: ScanSummary, today: CalendarDay) -> String {
        if let detail = details[scan.id] { return detail }
        let day = DayText.monthDay(CalendarDay(scan.scannedAt, in: clock.calendar), today: today, clock: clock)
        let detail = String(localized: "\(CollectionText.name(scan.collection)) · \(day)", bundle: #bundle)
        details[scan.id] = detail
        return detail
    }

    /// Keeps the search, its words single-spaced, and reports how many it found, never what (M19); a search already
    /// kept isn't reported again. Never from an empty field (M5).
    private func save() {
        let search = terms.joined(separator: " ")
        guard !search.isEmpty, search != lastSaved else { return }
        lastSaved = search
        history.record(search: search)
        analytics.send(.searchSaved(resultCount: shown.count))
    }

    /// 08-05's line, from the collections of the matches elsewhere: "1 scan in Notes mentions “bike”.", "3 scans in
    /// Notes and Receipts mention “bike”." (the one with more first), "5 scans in other collections mention “bike”.".
    private static func elsewhereLine(_ collections: [BuiltInCollection], query: String) -> String {
        let count = collections.count
        let counts = Dictionary(collections.map { ($0, 1) }, uniquingKeysWith: +)
        let named = BuiltInCollection.allCases.filter { counts[$0] != nil }
            // Stable, so a tie keeps display order.
            .sorted { counts[$0, default: 0] > counts[$1, default: 0] }
            .map(CollectionText.name)
        switch named.count {
        case 1:
            return String(localized: "\(count) scans in \(named[0]) mention “\(query)”.", bundle: #bundle)
        case 2:
            return String(
                localized: "\(count) scans in \(named[0]) and \(named[1]) mention “\(query)”.", bundle: #bundle)
        default:
            return String(localized: "\(count) scans in other collections mention “\(query)”.", bundle: #bundle)
        }
    }
}
