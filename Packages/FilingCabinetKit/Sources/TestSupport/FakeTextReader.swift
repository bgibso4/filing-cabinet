import CoreGraphics
import Synchronization
import Understanding

/// Test double: answers each `read` with the next scripted step. The last step repeats once the script runs out.
public final class FakeTextReader: TextReader {
    /// One scripted answer.
    public enum Step: Sendable {
        /// Return this page, after waiting `delay`.
        case page(PageText, delay: Duration = .zero)
        /// Throw this error.
        case failure(UnderstandingError)
    }

    private let script: Mutex<[Step]>
    private let calls = Mutex(0)

    public init(_ steps: [Step]) {
        script = Mutex(steps)
    }

    /// How many times `read` has been called.
    public var readCount: Int { calls.withLock { $0 } }

    public func read(_ page: CGImage) async throws(UnderstandingError) -> PageText {
        calls.withLock { $0 += 1 }
        let step = script.withLock { steps -> Step in
            guard let first = steps.first else { return .page(PageText(lines: [])) }
            if steps.count > 1 { steps.removeFirst() }
            return first
        }
        switch step {
        case .page(let text, let delay):
            if delay > .zero {
                // A cancelled wait just ends the delay early; the scripted page is still returned.
                try? await Task.sleep(for: delay)
            }
            return text
        case .failure(let error):
            throw error
        }
    }

    /// Always reads the synthetic receipt's three lines.
    public static func readsCityPharmacy() -> FakeTextReader {
        FakeTextReader([
            .page(
                PageText(lines: [
                    TextLine(text: "CITY PHARMACY", box: CGRect(x: 0.08, y: 0.06, width: 0.6, height: 0.05)),
                    TextLine(text: "Batteries AA", box: CGRect(x: 0.08, y: 0.12, width: 0.27, height: 0.02)),
                    TextLine(text: "TOTAL 12.40", box: CGRect(x: 0.08, y: 0.15, width: 0.25, height: 0.02)),
                ]))
        ])
    }
}
