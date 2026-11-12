import Core
import CoreGraphics
import Foundation
import Observation
import Understanding

/// One review's suggestion from the on-device model: whether review shows the card or the sheet, the one wait for
/// the filing call, what it filled in, its analytics (M10, never content) and, after Save, the words call.
///
/// The wait is `waitLimit` from when the card appears (M6). A rescan within it asks again for the new pages. When it
/// passes first, the card grows into the sheet and a late answer is dropped; save and discard end it too. Off, or with
/// the model unavailable, review is the sheet and nothing is asked.
@Observable
final class ReviewSuggestion {
    /// What a suggestion fills in, field by field.
    struct Fill: Equatable {
        var title: String?
        var collection: BuiltInCollection?
    }

    private(set) var presentation: ReviewPresentation
    /// "Suggested: City Pharmacy receipt, Receipts" once a suggestion fills the fields, for VoiceOver and the haptic.
    private(set) var announcement: String?

    @ObservationIgnored private let suggester: any ScanSuggester
    @ObservationIgnored private let waitLimit: Duration
    @ObservationIgnored private let analytics: any Analytics
    @ObservationIgnored private let wordsWriter: SearchWordsWriter
    /// Whether this review asks the model: suggestions were on and the model available when it began.
    @ObservationIgnored private let asks: Bool
    /// The filing call for the current pages.
    @ObservationIgnored private var call: Task<Void, Never>?
    @ObservationIgnored private var limit: Task<Void, Never>?
    /// True once the suggestion landed, the limit passed, or save or discard ended the wait.
    @ObservationIgnored private var isWaitOver = false
    /// What the suggestion filled in, so save can tell whether the user changed it.
    @ObservationIgnored private var filled = Fill()

    init(
        suggester: any ScanSuggester,
        isOn: Bool,
        waitLimit: Duration,
        analytics: any Analytics,
        wordsWriter: SearchWordsWriter
    ) {
        self.suggester = suggester
        self.waitLimit = waitLimit
        self.analytics = analytics
        self.wordsWriter = wordsWriter
        asks = suggester.answers(whenOn: isOn)
        presentation = asks ? .card(isReading: true) : .sheet
        if isOn && !asks { analytics.send(.suggestionOutcome(.unavailable)) }
    }

    /// The card opened by hand: the full sheet, still filled if the suggestion lands within the wait.
    func openSheet() {
        presentation = .sheet
    }

    /// The card has appeared: the wait starts, once.
    func startWaiting() {
        guard asks, limit == nil, !isWaitOver else { return }
        limit = Task { [waitLimit] in
            do {
                try await Task.sleep(for: waitLimit)
            } catch {
                return  // the wait ended first
            }
            limitPassed()
        }
    }

    /// Once `reading` ends, asks the model about these pages, replacing (and cancelling) the call for earlier ones.
    /// When it lands, `fill` is handed the suggestion's usable title and collection and returns what it filled in:
    /// the fields the user hasn't touched.
    func ask(after reading: Task<ScanReading, Never>, firstPage: CGImage?, fill: @escaping (Fill) -> Fill) {
        call?.cancel()
        call = nil
        guard asks, !isWaitOver else { return }
        call = Task { [suggester] in
            let found = await reading.value
            guard !Task.isCancelled else { return }
            let suggestion = await suggester.suggestFiling(
                SuggestionInput(
                    searchText: found.searchText, firstPage: firstPage, collections: SuggestionCollection.builtIns))
            // Cancelled: a rescan, the limit, save or discard came first, and the answer is no longer wanted.
            guard !Task.isCancelled else { return }
            landed(suggestion, fill: fill)
        }
    }

    /// A rescan put the fallback back in the title, so the suggested title is no longer what it shows.
    func titleWasReset() {
        filled.title = nil
    }

    /// No more suggestions this review: saved or discarded.
    func endWait() {
        isWaitOver = true
        call?.cancel()
        call = nil
        limit?.cancel()
    }

    /// At save: whether the user changed what the suggestion filled in (M10). Nothing when it filled nothing.
    func reportChanges(savedTitle: String, savedCollection: BuiltInCollection) {
        guard filled != Fill() else { return }
        analytics.send(
            .suggestionChanged(
                title: filled.title.map { $0 != savedTitle } ?? false,
                collection: filled.collection.map { $0 != savedCollection } ?? false))
    }

    /// After Save, once the text is read: the words call for the saved scan, when this review asks the model.
    func writeWords(
        for id: ScanID, reading found: ScanReading, firstPage: CGImage?, title: String, collection: BuiltInCollection
    ) {
        guard asks else { return }
        wordsWriter.write(
            for: id,
            input: SuggestionInput(
                searchText: found.searchText, firstPage: firstPage, collections: SuggestionCollection.builtIns),
            title: title,
            collectionName: SuggestionCollection.builtIn(collection).name
        )
    }

    /// Too slow: the card grows into the sheet with the text-rule title, and a late suggestion is dropped (M6).
    private func limitPassed() {
        guard !isWaitOver else { return }
        endWait()
        presentation = .sheet
        analytics.send(.suggestionOutcome(.timedOut))
    }

    /// A suggestion with neither a title nor a known collection failed, and the sheet shows.
    private func landed(_ suggestion: ScanSuggestion?, fill: (Fill) -> Fill) {
        call = nil
        endWait()
        let usable = Fill(
            title: suggestion?.title, collection: suggestion?.collectionID.flatMap(BuiltInCollection.init(rawValue:)))
        guard usable != Fill() else {
            presentation = .sheet
            analytics.send(.suggestionOutcome(.failed))
            return
        }
        analytics.send(.suggestionOutcome(.arrived))
        filled = fill(usable)
        announcement = Self.announcement(for: filled)
        if case .card = presentation { presentation = .card(isReading: false) }
    }

    /// "Suggested: City Pharmacy receipt, Receipts", or just the part filled in; nil when nothing was.
    private static func announcement(for filled: Fill) -> String? {
        switch (filled.title, filled.collection.map(CollectionText.name)) {
        case (let title?, let name?): String(localized: "Suggested: \(title), \(name)", bundle: #bundle)
        case (let title?, nil): String(localized: "Suggested: \(title)", bundle: #bundle)
        case (nil, let name?): String(localized: "Suggested: \(name)", bundle: #bundle)
        case (nil, nil): nil
        }
    }
}
