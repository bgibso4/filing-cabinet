/// Why a page could not be understood.
public enum UnderstandingError: Error, Equatable {
    /// Vision failed to run on the page.
    case recognitionFailed
}
