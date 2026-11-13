import Core
import Library
import Understanding

/// The split's second model call, after Save: asks for a saved scan's hidden search words and stores them with the
/// prompt version. A call that fails, is cancelled, times out or is cut off by the app leaving stores nothing, so the
/// scan keeps no version and the background pass fills it in later. Nothing is shown either way.
///
/// A words call waits while the next review's filing call runs (`isFilingUnderWay`), so that call has the model to
/// itself; it checks every `filingRecheck`. The call's time limit counts from when it starts, not from Save.
public final class SearchWordsWriter {
    /// How often a waiting words call looks again whether the filing call is done.
    private static let filingRecheck = Duration.milliseconds(250)

    /// True while a review's filing call runs, from when the review asks until the call ends or the review does.
    /// Set by that review; only one review runs at a time.
    package var isFilingUnderWay = false

    private let suggester: any ScanSuggester
    private let library: any ScanLibrary
    private let backgroundTime: any BackgroundTime
    private let callLimit: Duration
    private let filingRecheck: Duration
    /// Words calls started (or waiting to) and not yet ended.
    private var writesUnderWay = 0

    public convenience init(suggester: any ScanSuggester, library: any ScanLibrary, backgroundTime: any BackgroundTime)
    {
        self.init(
            suggester: suggester,
            library: library,
            backgroundTime: backgroundTime,
            callLimit: BoundedWordsCall.limit,
            filingRecheck: Self.filingRecheck)
    }

    /// `callLimit` and `filingRecheck` are shortened only by tests.
    package init(
        suggester: any ScanSuggester,
        library: any ScanLibrary,
        backgroundTime: any BackgroundTime,
        callLimit: Duration,
        filingRecheck: Duration = SearchWordsWriter.filingRecheck
    ) {
        self.suggester = suggester
        self.library = library
        self.backgroundTime = backgroundTime
        self.callLimit = callLimit
        self.filingRecheck = filingRecheck
    }

    /// True while a words call after Save is waiting or running; the background pass waits behind it.
    public var isWriting: Bool { writesUnderWay > 0 }

    /// Starts the words call for the scan saved as `title` in the collection named `collectionName`, holding
    /// background time (from now, so leaving the app while it waits is covered too) until it ends. Returns at once;
    /// the task is for tests to await.
    @discardableResult
    package func write(for id: ScanID, input: SuggestionInput, title: String, collectionName: String)
        -> Task<Void, Never>
    {
        let task = Task { [suggester, library, callLimit] in
            await waitForFiling()
            guard !Task.isCancelled else {
                ScreenModelsLog.logger.info("Search words: cancelled before the call, left for the background pass")
                return
            }
            let words = await BoundedWordsCall.words(
                from: suggester, input: input, title: title, collectionName: collectionName, limit: callLimit)
            guard let words, !Task.isCancelled else {
                ScreenModelsLog.logger.info("Search words: none stored, left for the background pass")
                return
            }
            library.updateSearchWords(words, version: ScanSuggestion.promptVersion, for: id)
            ScreenModelsLog.logger.info("Search words: \(words.count, privacy: .public) stored")
        }
        writesUnderWay += 1
        let end = backgroundTime.begin("Search words") { task.cancel() }
        Task {
            await task.value
            end()
            writesUnderWay -= 1
        }
        return task
    }

    private func waitForFiling() async {
        while isFilingUnderWay, !Task.isCancelled {
            // A cancelled sleep means background time ran out; the loop then ends and nothing is asked.
            try? await Task.sleep(for: filingRecheck)
        }
    }
}
