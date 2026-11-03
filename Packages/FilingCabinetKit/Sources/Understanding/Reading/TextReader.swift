import CoreGraphics

/// Reads the text on a page image. The seam between capture and understanding.
public protocol TextReader: Sendable {
    func read(_ page: CGImage) async throws(UnderstandingError) -> PageText
}
