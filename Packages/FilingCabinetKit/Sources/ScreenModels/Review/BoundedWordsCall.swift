import Understanding

/// One words call to the model with a time limit, shared by the call after Save (`SearchWordsWriter`) and the
/// background pass (`SearchWordsPass`).
enum BoundedWordsCall {
    /// A model call was once seen to hang for 10+ minutes; this one is cancelled long before.
    static let limit = Duration.seconds(30)

    /// The call's words, or nil if it failed, `limit` passed first, or the caller was cancelled. Unstructured tasks
    /// race the call, so this returns at the limit even when the call ignores cancellation (a task group would wait
    /// for it); the call is then cancelled and left to end on its own.
    static func words(
        from suggester: any ScanSuggester,
        input: SuggestionInput,
        title: String,
        collectionName: String,
        limit: Duration
    ) async -> [String]? {
        let call = Task { await suggester.suggestWords(input, title: title, collectionName: collectionName) }
        let timer = Task {
            // A cancelled sleep means the call ended first or the caller was cancelled: either way, stop waiting.
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
