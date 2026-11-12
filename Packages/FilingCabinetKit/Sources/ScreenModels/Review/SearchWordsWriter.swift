import Core
import Library
import Understanding

/// The split's second model call, after Save: asks for a saved scan's hidden search words and stores them with the
/// prompt version. A call that fails, is cancelled, times out or is cut off by the app leaving stores nothing, so the
/// scan keeps no version and the background pass fills it in later. Nothing is shown either way.
public final class SearchWordsWriter {
    /// A model call was once seen to hang for 10+ minutes; this one is cancelled long before.
    private static let callLimit = Duration.seconds(30)

    private let suggester: any ScanSuggester
    private let library: any ScanLibrary
    private let backgroundTime: any BackgroundTime
    private let callLimit: Duration

    public convenience init(suggester: any ScanSuggester, library: any ScanLibrary, backgroundTime: any BackgroundTime)
    {
        self.init(suggester: suggester, library: library, backgroundTime: backgroundTime, callLimit: Self.callLimit)
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

    /// Starts the words call for the scan saved as `title` in the collection named `collectionName`, holding
    /// background time until it ends. Returns at once; the task is for tests to await.
    @discardableResult
    package func write(for id: ScanID, input: SuggestionInput, title: String, collectionName: String)
        -> Task<Void, Never>
    {
        let task = Task { [suggester, library, callLimit] in
            let words = await Self.words(
                from: suggester, input: input, title: title, collectionName: collectionName, limit: callLimit)
            guard let words, !Task.isCancelled else {
                ScreenModelsLog.logger.info("Search words: none stored, left for the background pass")
                return
            }
            library.updateSearchWords(words, version: ScanSuggestion.promptVersion, for: id)
            ScreenModelsLog.logger.info("Search words: \(words.count, privacy: .public) stored")
        }
        let end = backgroundTime.begin("Search words") { task.cancel() }
        Task {
            await task.value
            end()
        }
        return task
    }

    /// The call's words, or nil if it failed or `limit` passed first (the call is then cancelled).
    private static func words(
        from suggester: any ScanSuggester,
        input: SuggestionInput,
        title: String,
        collectionName: String,
        limit: Duration
    ) async -> [String]? {
        await withTaskGroup(of: [String]?.self) { group in
            group.addTask { await suggester.suggestWords(input, title: title, collectionName: collectionName) }
            group.addTask {
                // A cancelled sleep only means the call ended first.
                try? await Task.sleep(for: limit)
                return nil
            }
            defer { group.cancelAll() }
            guard let first = await group.next() else { return nil }
            return first
        }
    }
}
