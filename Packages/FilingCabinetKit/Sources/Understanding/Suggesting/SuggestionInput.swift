import CoreGraphics

/// Everything the suggester reads for one scan (M2).
public struct SuggestionInput: Sendable {
    /// Each page's recognized text, page 1 first.
    package let pageTexts: [String]
    /// Page 1, used only when the suggester sends the image.
    package let firstPage: CGImage?
    /// The collections that exist now; the answer must be one of their ids.
    package let collections: [SuggestionCollection]

    package init(pageTexts: [String], firstPage: CGImage?, collections: [SuggestionCollection]) {
        self.pageTexts = pageTexts
        self.firstPage = firstPage
        self.collections = collections
    }
}
