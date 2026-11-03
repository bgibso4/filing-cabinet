import CoreGraphics
import Foundation
import Vision

/// Reads a page with Vision's `RecognizeDocumentsRequest`: language-corrected, US English.
struct DocumentRecognitionReader: TextReader {
    private let onPerform: @Sendable () -> Void

    /// - Parameter onPerform: called right before Vision runs (tests use it to check the thread).
    init(onPerform: @escaping @Sendable () -> Void = {}) {
        self.onPerform = onPerform
    }

    @concurrent
    func read(_ page: CGImage) async throws(UnderstandingError) -> PageText {
        let start = ContinuousClock.now
        let documents = try await recognize(page)
        let lines = documents.flatMap { observation in
            observation.document.text.lines.map { line in
                TextLine(text: line.transcript, box: VisionBox.topLeft(fromBottomLeft: line.boundingBox.cgRect))
            }
        }
        UnderstandingLog.logger.info(
            "document reader: \(lines.count, privacy: .public) lines in \(ContinuousClock.now - start, privacy: .public)"
        )
        return PageText(lines: lines)
    }

    /// The document's title as Vision sees it, or nil when there is none or Vision fails. Bake-off only (M23).
    @concurrent
    package func documentTitle(_ page: CGImage) async -> String? {
        do {
            return try await recognize(page).first?.document.title?.transcript
        } catch {
            return nil
        }
    }

    private func recognize(_ page: CGImage) async throws(UnderstandingError) -> [DocumentObservation] {
        var request = RecognizeDocumentsRequest()
        request.textRecognitionOptions.useLanguageCorrection = true
        request.textRecognitionOptions.recognitionLanguages = [Locale.Language(identifier: "en-US")]

        onPerform()
        do {
            return try await request.perform(on: page)
        } catch {
            UnderstandingLog.logger.error("document reader failed: \(String(describing: error), privacy: .private)")
            throw .recognitionFailed
        }
    }
}
