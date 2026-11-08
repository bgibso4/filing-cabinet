import Core

/// One scan in Trash (09-01).
package struct TrashTile: Identifiable, Equatable {
    package let id: ScanID
    package let title: String
    package let collection: BuiltInCollection
    /// "2 days left".
    package let daysLeftText: String
    /// Orange: the last 7 days.
    package let isSoon: Bool
}
