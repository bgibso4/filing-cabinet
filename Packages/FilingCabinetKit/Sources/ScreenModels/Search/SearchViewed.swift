import Core

/// A recently viewed scan, as Search shows it before typing (08-02).
package struct SearchViewed: Equatable, Identifiable {
    package let id: ScanID
    package let title: String
    /// The dot's colour.
    package let collection: BuiltInCollection
}
