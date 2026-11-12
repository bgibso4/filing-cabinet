import Testing

/// The eval's timeout race; no model runs here.
struct TimedCallTests {
    /// Answers after `delay`, or nil when cancelled first.
    private static func slow(_ delay: Duration) async -> String? {
        do {
            try await Task.sleep(for: delay)
        } catch {
            return nil
        }
        return "Answer"
    }

    @Test func answerInTimeIsKept() async {
        let answer = await TimedCall.run(limit: .seconds(10)) { await Self.slow(.milliseconds(1)) }

        #expect(answer.answer == "Answer")
        #expect(!answer.timedOut)
        #expect(answer.milliseconds < 10_000)
    }

    @Test func slowCallIsCancelledAtTheLimit() async {
        let start = ContinuousClock.now
        let answer = await TimedCall.run(limit: .milliseconds(50)) { await Self.slow(.seconds(60)) }

        #expect(answer.answer == nil)
        #expect(answer.timedOut)
        #expect(ContinuousClock.now - start < .seconds(5))
    }
}
