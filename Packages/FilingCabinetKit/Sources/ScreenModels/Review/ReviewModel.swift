import Core
import CoreGraphics
import Foundation
import Library
import Observation
import Understanding

/// The review after the camera: the pages, the title (read from page 1 unless typed), the collection and expiry, then
/// save or discard. Reading runs once per page set; save waits for it at most `readingWaitLimit` and adds the search
/// text afterwards if it was still reading (M2).
///
/// With suggestions on and the model available, review starts as the card: once reading ends, the model suggests a
/// title and collection (`ReviewSuggestion`), filling only the fields the user hasn't touched.
@Observable
public final class ReviewModel: ExpiryEditing {
    package private(set) var pages: [CGImage]
    /// 0-based. The pager writes it. Another page starts unzoomed.
    package var currentPage = 0 {
        didSet {
            if currentPage != oldValue { isPageZoomed = false }
        }
    }
    /// Whether the current page is zoomed past 1×; the page writes it.
    package var isPageZoomed = false
    package private(set) var title: String
    /// "Scan · Oct 12": what a scan with no readable title, or a cleared one, is called (A5, M3).
    package let fallbackTitle: String
    package private(set) var collection: BuiltInCollection?
    package private(set) var expiryOverride: ExpiryOverride?
    package private(set) var isSaving = false
    package private(set) var saveAlert: SaveAlert?
    /// What reading the current pages found; nil until it finishes.
    private var finishedReading: ScanReading?

    @ObservationIgnored private let input: ReviewInput
    @ObservationIgnored private let reader: ScanReader
    @ObservationIgnored private let library: any ScanLibrary
    @ObservationIgnored private let clock: AppClock
    @ObservationIgnored private let analytics: any Analytics
    @ObservationIgnored private let readingWaitLimit: Duration
    private let suggestion: ReviewSuggestion
    /// One id for the whole review, so a retried save is the same scan.
    @ObservationIgnored private let id = ScanID()
    /// True once the user has typed in the title field; reading never overwrites it then.
    @ObservationIgnored private var isTitleEdited = false
    /// True once the user has picked a collection, or the scan began inside one; a suggestion never overwrites it.
    @ObservationIgnored private var isCollectionChosen: Bool
    /// Reading of the current pages; replaced (and the old one cancelled) when a rescan replaces them.
    @ObservationIgnored private var reading: Task<ScanReading, Never>?

    public init(
        input: ReviewInput,
        reader: ScanReader,
        library: any ScanLibrary,
        clock: AppClock,
        analytics: any Analytics,
        readingWaitLimit: Duration,
        suggester: any ScanSuggester,
        suggestionsOn: Bool,
        suggestionWaitLimit: Duration,
        wordsWriter: SearchWordsWriter
    ) {
        self.input = input
        self.reader = reader
        self.library = library
        self.clock = clock
        self.analytics = analytics
        self.readingWaitLimit = readingWaitLimit
        suggestion = ReviewSuggestion(
            suggester: suggester,
            isOn: suggestionsOn,
            waitLimit: suggestionWaitLimit,
            analytics: analytics,
            wordsWriter: wordsWriter
        )
        pages = input.pages
        collection = input.preselected
        isCollectionChosen = input.preselected != nil
        fallbackTitle = Self.fallbackTitle(scannedAt: input.scannedAt, clock: clock)
        title = fallbackTitle
    }

    // MARK: Pages

    /// "1 page", or "Page 2 of 3" with more than one.
    package var pageCountText: String {
        pages.count == 1 ? String(localized: "\(1) pages", bundle: #bundle) : pageAccessibilityLabel
    }

    /// "Page 2 of 3".
    package var pageAccessibilityLabel: String {
        String(localized: "Page \(currentPage + 1) of \(pages.count)", bundle: #bundle)
    }

    // MARK: Title

    /// Ignored while saving, as every choice is: the save has already taken them.
    package func editTitle(_ text: String) {
        guard !isSaving else { return }
        title = text
        isTitleEdited = true
    }

    // MARK: Collection

    /// "Collection · required" until one is chosen.
    package var collectionLabel: String {
        collection == nil
            ? String(localized: "Collection · required", bundle: #bundle)
            : String(localized: "Collection", bundle: #bundle)
    }

    package var collectionValue: String {
        collection.map(CollectionText.name) ?? String(localized: "Choose a collection", bundle: #bundle)
    }

    package var collectionOptions: [CollectionOption] { CollectionOption.all(lifespans: library.lifespans) }

    /// Ignored while saving.
    public func choose(_ collection: BuiltInCollection) {
        guard !isSaving else { return }
        self.collection = collection
        isCollectionChosen = true
    }

    // MARK: Expiry

    package var isExpiryEnabled: Bool { collection != nil }

    /// "Set by the collection" until a collection is chosen, then "3 months · until Jan 9, 2027".
    package var expiryValue: String {
        guard let collection else { return String(localized: "Set by the collection", bundle: #bundle) }
        return ExpiryText.reviewValue(
            collectionLifespan: library.lifespans[collection],
            override: expiryOverride,
            scanDay: scanDay,
            today: clock.today,
            clock: clock)
    }

    /// The collection default first, then every lifespan, shortest first and Forever last (07-06). Empty until a
    /// collection is chosen. The scan day is today, so no choice has passed.
    package var expiryOptions: [ExpiryOption] {
        guard let collection else { return [] }
        return ExpiryChoices(scanDay: scanDay, today: clock.today, lifespans: library.lifespans, clock: clock)
            .options(collection: collection, override: expiryOverride)
    }

    /// The calendar and locale "Choose a date…" shows its days in (M6).
    package var calendar: Calendar { clock.calendar }
    package var locale: Locale { clock.locale }

    /// The first day "Choose a date…" offers: today.
    package var earliestCustomDate: Date { clock.today.date(in: clock.calendar) }

    /// Ignored while saving.
    package func chooseExpiry(_ override: ExpiryOverride?) {
        guard !isSaving else { return }
        expiryOverride = override
    }

    /// Keeps the scan through the end of `date`'s day. A day before today is refused, and so is any day while saving.
    package func chooseExpiryDate(_ date: Date) {
        guard !isSaving else { return }
        let day = CalendarDay(date, in: clock.calendar)
        guard day >= clock.today else { return }
        expiryOverride = .lastDay(day)
    }

    // MARK: Save

    package var canSave: Bool { collection != nil && !isSaving }

    /// "Save", or "Save to Receipts" once a collection is chosen.
    package var saveTitle: String {
        guard let collection else { return String(localized: "Save", bundle: #bundle) }
        return String(localized: "Save to \(CollectionText.name(collection))", bundle: #bundle)
    }

    /// Saves the scan, waiting at most `readingWaitLimit` for reading. Saved before reading ends, the scan gets its
    /// search text once reading does (M2). Nil when there is nothing to save yet or the save failed (`saveAlert`).
    package func save() async -> SavedScan? {
        guard let collection, !isSaving else { return nil }
        isSaving = true
        defer { isSaving = false }
        // The save takes the title and collection as they are now; a suggestion still on its way is dropped and
        // records no outcome (none of M10's fits a save that came first).
        suggestion.endWait()
        let task = reading ?? beginReading()
        let found = await readingResult(within: readingWaitLimit)
        let title = savedTitle
        let draft = ScanDraft(
            id: id,
            title: title,
            collection: collection,
            scannedAt: input.scannedAt,
            expiryOverride: expiryOverride,
            pages: pages,
            searchText: found?.searchText
        )
        do {
            try await library.save(draft)
        } catch {
            saveAlert = SaveAlert(error)
            suggestion.saveFailed()
            analytics.send(.saveFailed(reason: error == .diskFull ? .diskFull : .writeFailed))
            return nil
        }
        analytics.send(.scanSaved(pageCount: pages.count, collection: collection))
        suggestion.reportChanges(savedTitle: title, savedCollection: collection)
        let firstPage = pages.first
        if let found {
            suggestion.writeWords(for: id, reading: found, firstPage: firstPage, title: title, collection: collection)
        } else {
            // Only now does the record exist, so the text can't be dropped for want of one (M2). A cancelled reading
            // stopped part-way; its partial text is not the scan's. Background time covers only the words call, not
            // this wait for reading: if the app is left first, the background pass fills the words later.
            Task { [library, id, suggestion] in
                let found = await task.value
                guard !task.isCancelled else { return }
                library.updateSearchText(found.searchText, for: id)
                suggestion.writeWords(
                    for: id, reading: found, firstPage: firstPage, title: title, collection: collection)
            }
        }
        return SavedScan(
            id: id,
            announcement: String(localized: "Saved to \(CollectionText.name(collection))", bundle: #bundle)
        )
    }

    /// The alert's Try again.
    package func retrySave() async -> SavedScan? {
        saveAlert = nil
        return await save()
    }

    /// The alert's Not now: the pages stay in review.
    package func dismissSaveAlert() {
        saveAlert = nil
    }

    // MARK: Discard

    /// "The page you just scanned won’t be saved." / "The 3 pages you just scanned won’t be saved."
    package var discardMessage: String {
        String(localized: "The \(pages.count) pages you just scanned won’t be saved.", bundle: #bundle)
    }

    /// Ignored while saving: the save is already under way.
    package func discard() {
        guard !isSaving else { return }
        reading?.cancel()
        suggestion.endWait()
        analytics.send(.scanCancelled(stage: .review))
    }

    // MARK: Reading

    /// The review has appeared: starts the suggestion's wait limit, then reads the pages, once per page set, and
    /// returns when reading has finished (the suggestion may come later).
    public func startReading() async {
        suggestion.startWaiting()
        _ = await (reading ?? beginReading()).value
    }

    /// A finished rescan: its pages replace these, and they are read afresh (and suggested for, within the wait). A
    /// title the user hasn't typed goes back to the fallback until the new pages are read; a collection the suggestion
    /// picked goes back to unchosen.
    /// Ignored while saving, so the pages being saved are the ones read.
    package func replacePages(_ pages: [CGImage]) {
        guard !isSaving else { return }
        reading?.cancel()
        self.pages = pages
        currentPage = 0
        isPageZoomed = false
        finishedReading = nil
        // What the suggestion filled and the user hasn't touched goes: the title to the text rule, the collection to
        // unchosen (a preselected one is never filled, so it stays).
        let resetsCollection = !isCollectionChosen && suggestion.filled.collection != nil
        if !isTitleEdited { title = fallbackTitle }
        if resetsCollection { collection = input.preselected }
        suggestion.forgetFilled(title: !isTitleEdited, collection: resetsCollection)
        beginReading()
    }

    // MARK: Private

    private static func fallbackTitle(scannedAt: Date, clock: AppClock) -> String {
        let day = CalendarDay(scannedAt, in: clock.calendar)
        return String(localized: "Scan · \(DayText.monthDay(day, clock: clock))", bundle: #bundle)
    }

    private var scanDay: CalendarDay { CalendarDay(input.scannedAt, in: clock.calendar) }

    /// The typed or read title, or the fallback when it's blank (M3).
    private var savedTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallbackTitle : trimmed
    }

    @discardableResult
    private func beginReading() -> Task<ScanReading, Never> {
        let task = Task { [reader, pages] in
            let found = await reader.read(pages)
            // A cancelled reading belongs to pages a rescan replaced; its result is dropped.
            if !Task.isCancelled { readingFinished(found) }
            return found
        }
        reading = task
        suggestion.ask(after: task, firstPage: pages.first) { [self] usable in fill(usable) }
        return task
    }

    /// Fills the fields the user hasn't touched with the suggestion's, and returns what it filled.
    private func fill(_ usable: ReviewSuggestion.Fill) -> ReviewSuggestion.Fill {
        var filled = ReviewSuggestion.Fill()
        if !isTitleEdited, let suggested = usable.title {
            title = suggested
            filled.title = suggested
        }
        if !isCollectionChosen, let suggested = usable.collection {
            collection = suggested
            filled.collection = suggested
        }
        return filled
    }

    private func readingFinished(_ found: ScanReading) {
        finishedReading = found
        if !isTitleEdited { title = found.title ?? fallbackTitle }
        if found.failedPages > 0 { analytics.send(.textReadingFailed(failedPages: found.failedPages)) }
    }

    /// What reading found, or nil if it hasn't finished within `limit`. Awaiting `Task.value` ignores cancellation,
    /// so the task group would wait for the loser; the race watches `finishedReading`, which stops when cancelled.
    private func readingResult(within limit: Duration) async -> ScanReading? {
        await withTaskGroup(of: ScanReading?.self) { group in
            group.addTask { await self.nextFinishedReading() }
            group.addTask {
                // A cancelled sleep only means reading won the race.
                try? await ContinuousClock().sleep(for: limit)
                return nil
            }
            defer { group.cancelAll() }
            guard let first = await group.next() else { return nil }
            return first
        }
    }

    /// The finished reading, as soon as there is one; nil if cancelled first.
    private func nextFinishedReading() async -> ScanReading? {
        for await found in Observations({ self.finishedReading }) {
            if let found { return found }
        }
        return nil
    }
}

// MARK: - Suggestion

extension ReviewModel {
    /// Public for the snapshot tests, which wait for the suggestion to land.
    public var presentation: ReviewPresentation { suggestion.presentation }

    /// "Suggested: City Pharmacy receipt, Receipts" once a suggestion fills the fields, for VoiceOver and the haptic.
    package var suggestionAnnouncement: String? { suggestion.announcement }

    /// Whether the collection is the user's (picked, or the scan began inside it) rather than empty or the
    /// suggestion's: the sheet's collection haptic plays only for a pick, as the suggestion has its own (M11).
    package var isCollectionPicked: Bool { isCollectionChosen }

    /// The card's line under the title (03-02): "Receipts · kept 3 months", "Documents · kept forever", or "Choose a
    /// collection" before there is one.
    package var cardLine: String {
        guard let collection else { return collectionValue }
        let name = CollectionText.name(collection)
        let lifespan = library.lifespans[collection]
        return lifespan == .forever
            ? String(localized: "\(name) · kept forever", bundle: #bundle)
            : String(localized: "\(name) · kept \(CollectionText.lifespanShort(lifespan))", bundle: #bundle)
    }

    /// The card tapped or dragged open: the full sheet. A suggestion landing within the wait still fills the fields
    /// the user hasn't touched.
    package func openSheet() {
        suggestion.openSheet()
    }
}
