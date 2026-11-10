import Core

/// A recently viewed scan, as Search shows it before typing (08-02).
package struct SearchViewed: Equatable, Identifiable {
    package let id: ScanID
    // periphery:ignore - Task 9 (Plan 4) shows it under the thumbnail; remove this when it lands
    package let title: String
    // periphery:ignore - Task 9 (Plan 4) shows it as the title's dot; remove this when it lands
    /// The dot's colour.
    package let collection: BuiltInCollection
}
