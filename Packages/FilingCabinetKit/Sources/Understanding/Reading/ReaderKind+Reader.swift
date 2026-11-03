import Core

extension ReaderKind {
    /// The production reader for this kind.
    package func makeReader() -> any TextReader {
        switch self {
        case .text: TextRecognitionReader()
        case .documents: DocumentRecognitionReader()
        }
    }
}
