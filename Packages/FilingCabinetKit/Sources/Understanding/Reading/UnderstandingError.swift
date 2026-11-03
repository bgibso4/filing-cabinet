/// Why a page could not be understood.
package enum UnderstandingError: Error, Equatable {
    /// Vision failed to run on the page.
    case recognitionFailed
}
