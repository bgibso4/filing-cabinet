import CoreGraphics

/// One recognized line of text and where it sits on the page.
package struct TextLine: Sendable, Equatable {
    package let text: String
    /// Normalized to 0...1 with the origin at the page's top-left.
    package let box: CGRect

    package init(text: String, box: CGRect) {
        self.text = text
        self.box = box
    }
}
