import CoreGraphics

/// One recognized line of text and where it sits on the page.
public struct TextLine: Sendable, Equatable {
    public let text: String
    /// Normalized to 0...1 with the origin at the page's top-left.
    public let box: CGRect

    public init(text: String, box: CGRect) {
        self.text = text
        self.box = box
    }
}
