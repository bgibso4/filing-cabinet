import CoreGraphics
import Foundation
import Vision

/// Reads a page with Vision's `RecognizeTextRequest`: accurate, language-corrected, US English.
struct TextRecognitionReader: TextReader {
    private let onPerform: @Sendable () -> Void

    /// - Parameter onPerform: called right before Vision runs (tests use it to check the thread).
    init(onPerform: @escaping @Sendable () -> Void = {}) {
        self.onPerform = onPerform
    }

    @concurrent
    func read(_ page: CGImage) async throws(UnderstandingError) -> PageText {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = [Locale.Language(identifier: "en-US")]

        let start = ContinuousClock.now
        onPerform()
        let observations: [RecognizedTextObservation]
        do {
            observations = try await request.perform(on: page)
        } catch {
            UnderstandingLog.logger.error("text reader failed: \(String(describing: error), privacy: .private)")
            throw .recognitionFailed
        }
        let lines = observations.compactMap { observation -> TextLine? in
            guard let best = observation.topCandidates(1).first else { return nil }
            return TextLine(text: best.string, box: VisionBox.topLeft(fromBottomLeft: observation.boundingBox.cgRect))
        }
        UnderstandingLog.logger.info(
            "text reader: \(lines.count, privacy: .public) lines in \(ContinuousClock.now - start, privacy: .public)")
        return PageText(lines: lines)
    }
}
