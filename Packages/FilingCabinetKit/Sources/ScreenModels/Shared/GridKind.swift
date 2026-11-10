import Core

/// Which grid a screen shows.
public enum GridKind: Hashable {
    case collection(BuiltInCollection)
    case recent
    case all
    /// The scans the person hearted, in the order they set (B10).
    case favorites

    /// The collection a new scan from this grid starts in, or nil when the grid has none.
    package var preselection: BuiltInCollection? {
        if case .collection(let collection) = self { collection } else { nil }
    }
}
