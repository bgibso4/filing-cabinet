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

    /// The call's words, or nil if it failed, `limit` passed first, or the writer was cancelled. Unstructured tasks
    /// race the call, so this returns at the limit even when the call ignores cancellation (a task group would wait
    /// for it); the call is then cancelled and left to end on its own.
    private static func words(
        from suggester: any ScanSuggester,
        input: SuggestionInput,
        title: String,
        collectionName: String,
        limit: Duration
    ) async -> [String]? {
        let call = Task { await suggester.suggestWords(input, title: title, collectionName: collectionName) }
        let timer = Task {
            // A cancelled sleep means the call ended first or the writer was cancelled: either way, stop waiting.
            try? await Task.sleep(for: limit)
        }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let first = FirstAnswer(continuation)
                Task {
                    let words = await call.value
                    timer.cancel()
                    first.give(words)
                }
                Task {
                    await timer.value
                    call.cancel()
                    first.give(nil)
                }
            }
        } onCancel: {
            timer.cancel()
        }
    }
}

/// Resumes the race's continuation once, with whichever answer comes first.
private final class FirstAnswer {
    private var continuation: CheckedContinuation<[String]?, Never>?

    init(_ continuation: CheckedContinuation<[String]?, Never>) {
        self.continuation = continuation
    }

    func give(_ words: [String]?) {
        continuation?.resume(returning: words)
        continuation = nil
    }
}
