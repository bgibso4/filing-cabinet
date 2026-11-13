import Core
import Library
import Understanding

/// The split's second model call, after Save: asks for a saved scan's hidden search words and stores them with the
/// prompt version. A call that fails, is cancelled, times out or is cut off by the app leaving stores nothing, so the
/// scan keeps no version and the background pass fills it in later. Nothing is shown either way.
public final class SearchWordsWriter {
    private let suggester: any ScanSuggester
    private let library: any ScanLibrary
    private let backgroundTime: any BackgroundTime
    private let callLimit: Duration
    /// Words calls started and not yet ended.
    private var writesUnderWay = 0

    public convenience init(suggester: any ScanSuggester, library: any ScanLibrary, backgroundTime: any BackgroundTime)
    {
        self.init(
            suggester: suggester, library: library, backgroundTime: backgroundTime, callLimit: BoundedWordsCall.limit)
    }

    /// `callLimit` is shortened only by tests.
    package init(
        suggester: any ScanSuggester, library: any ScanLibrary, backgroundTime: any BackgroundTime, callLimit: Duration
    ) {
        self.suggester = suggester
        self.library = library
        self.backgroundTime = backgroundTime
        self.callLimit = callLimit
    }

    /// True while a words call after Save is running; the background pass waits behind it.
    public var isWriting: Bool { writesUnderWay > 0 }

    /// Starts the words call for the scan saved as `title` in the collection named `collectionName`, holding
    /// background time until it ends. Returns at once; the task is for tests to await.
    @discardableResult
    package func write(for id: ScanID, input: SuggestionInput, title: String, collectionName: String)
        -> Task<Void, Never>
    {
        let task = Task { [suggester, library, callLimit] in
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
}
