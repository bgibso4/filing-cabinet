import Core
import Library
import Observation
import Understanding

/// Gives the library's scans that have no search words from this prompt version their words: scans saved before
/// Apple Intelligence, and scans whose words call after Save failed or was cut short (M9). Only while the app is in
/// the foreground: the app calls `resume()` at launch and on coming back, and `leftForeground()` on leaving, after
/// which `resume()` does nothing until `enteredForeground()` (the app's own work before `resume()` may outlast a stay).
///
/// One scan at a time, newest first. Each scan is asked about with its stored text, its own title and its
/// collection's name, and only its words change. A scan whose call fails or times out is skipped until the next
/// `resume()`. The list is asked for again before each scan, so a scan deleted or moved to Trash meanwhile is skipped.
///
/// The pass never competes with review for the model: `scanStarted()` stops it, call in flight included, and
/// `scanEnded()` starts it again. Between scans it waits while `isBusy` (a words call after Save), checking every
/// `busyRecheck`; a words call takes seconds, so the check costs nothing to speak of.
@MainActor
@Observable
public final class SearchWordsPass {
    /// How many of the library's scans have their words, of how many.
    package struct Progress: Equatable {
        package let done: Int
        package let total: Int
    }

    /// While the pass reads: how far it has got. Nil when it isn't reading or nothing is left.
    package private(set) var progress: Progress?

    /// How often a waiting pass looks again whether review is done with the model.
    private static let busyRecheck = Duration.seconds(1)

    @ObservationIgnored private let library: any ScanLibrary
    @ObservationIgnored private let today: Today
    @ObservationIgnored private let suggester: any ScanSuggester
    @ObservationIgnored private let preferences: AppPreferences
    @ObservationIgnored private let isBusy: () -> Bool
    @ObservationIgnored private let callLimit: Duration
    @ObservationIgnored private let busyRecheck: Duration
    @ObservationIgnored private var run: Task<Void, Never>?
    /// Tells the current run from one `pause()` has cancelled but which hasn't ended yet.
    @ObservationIgnored private var runNumber = 0
    /// The app launches into the foreground; `leftForeground()` and `enteredForeground()` keep this current.
    @ObservationIgnored private var isInForeground = true
    /// Between `scanStarted()` and `scanEnded()`.
    @ObservationIgnored private var isScanUnderWay = false

    /// `isBusy` is true while the model is wanted elsewhere between scans: a words call after Save.
    public convenience init(
        library: any ScanLibrary,
        today: Today,
        suggester: any ScanSuggester,
        preferences: AppPreferences,
        isBusy: @escaping () -> Bool
    ) {
        self.init(
            library: library,
            today: today,
            suggester: suggester,
            preferences: preferences,
            isBusy: isBusy,
            callLimit: BoundedWordsCall.limit,
            busyRecheck: Self.busyRecheck)
    }

    /// `callLimit` and `busyRecheck` are shortened only by tests.
    package init(
        library: any ScanLibrary,
        today: Today,
        suggester: any ScanSuggester,
        preferences: AppPreferences,
        isBusy: @escaping () -> Bool,
        callLimit: Duration,
        busyRecheck: Duration
    ) {
        self.library = library
        self.today = today
        self.suggester = suggester
        self.preferences = preferences
        self.isBusy = isBusy
        self.callLimit = callLimit
        self.busyRecheck = busyRecheck
    }

    /// Starts reading, unless it already is, the app isn't in the foreground, a scan is under way, the switch is off
    /// or the model can't answer.
    public func resume() {
        guard run == nil, isInForeground, !isScanUnderWay, isAllowed else { return }
        runNumber += 1
        let number = runNumber
        run = Task { [weak self] in
            await self?.readAll()
            self?.ended(number)
        }
    }

    /// Stops reading; the scan being read keeps no words and is read again on the next `resume()`.
    public func pause() {
        run?.cancel()
        run = nil
        progress = nil
    }

    /// A scan has started: reading stops, the call in flight too, so review has the model to itself; `resume()` waits
    /// for `scanEnded()`.
    public func scanStarted() {
        isScanUnderWay = true
        pause()
    }

    /// The scan has ended (saved, discarded or cancelled): reading starts again.
    public func scanEnded() {
        isScanUnderWay = false
        resume()
    }

    /// The app is in the foreground again; the caller resumes once its own launch work allows.
    public func enteredForeground() {
        isInForeground = true
    }

    /// The app has left the foreground: reading stops, and `resume()` waits for `enteredForeground()`.
    public func leftForeground() {
        isInForeground = false
        pause()
    }

    private var isAllowed: Bool { suggester.answers(whenOn: preferences.appleIntelligenceOn) }

    private func readAll() async {
        var tried: Set<ScanID> = []
        while !Task.isCancelled, isAllowed {
            await waitWhileBusy()
            guard !Task.isCancelled, isAllowed else { return }
            let needing = library.scansNeedingWords(version: ScanSuggestion.promptVersion)
            let inLibrary = LibraryShelf(
                scans: library.scans, lifespans: library.lifespans, today: today.day, calendar: today.calendar
            ).visible
            guard let id = needing.first(where: { !tried.contains($0) }) else { return }
            tried.insert(id)
            guard let scan = inLibrary.first(where: { $0.id == id }) else { continue }
            // Counted against one list, so the library's and this pass's idea of today can't disagree.
            let unread = Set(needing)
            progress = Progress(
                done: inLibrary.count { !unread.contains($0.id) }, total: inLibrary.count)
            await read(scan)
        }
    }

    /// Asks for the scan's words and stores them; a failure leaves the scan for the next run.
    private func read(_ scan: ScanSummary) async {
        let input = SuggestionInput(
            // A scan with no readable text still has its title and collection to go on.
            searchText: library.searchText(for: scan.id) ?? "",
            // Page 1 isn't decoded: the words call reads text only (`SuggestionPrompt.wordsPrompt`).
            firstPage: nil,
            collections: SuggestionCollection.builtIns)
        let words = await BoundedWordsCall.words(
            from: suggester,
            input: input,
            title: scan.title,
            collectionName: SuggestionCollection.builtIn(scan.collection).name,
            limit: callLimit)
        guard !Task.isCancelled else { return }
        guard let words else {
            ScreenModelsLog.logger.info("Search words pass: no words, left for the next run")
            return
        }
        library.updateSearchWords(words, version: ScanSuggestion.promptVersion, for: scan.id)
    }

    private func waitWhileBusy() async {
        while isBusy(), !Task.isCancelled {
            // A cancelled sleep means the pass was paused; the loop then ends.
            try? await Task.sleep(for: busyRecheck)
        }
    }

    /// The run ended by itself: nothing left, a switch turned off, or a pause (then a newer run may be going).
    private func ended(_ number: Int) {
        guard number == runNumber, run != nil else { return }
        run = nil
        progress = nil
    }
}
