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

    /// From a scan's stored or just-read text: its pages, split again where `ScanReader` joined them (pages with no
    /// text were left out then).
    package init(searchText: String, firstPage: CGImage?, collections: [SuggestionCollection]) {
        self.init(
            pageTexts: searchText.components(separatedBy: ScanReading.pageSeparator),
            firstPage: firstPage,
            collections: collections
        )
    }
}
