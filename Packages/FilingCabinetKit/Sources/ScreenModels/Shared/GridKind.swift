import Core

/// Which grid a screen shows.
public enum GridKind: Hashable {
    case collection(BuiltInCollection)
    case recent
    case all

    /// The collection a new scan from this grid starts in, or nil when the grid has none.
    package var preselection: BuiltInCollection? {
        if case .collection(let collection) = self { collection } else { nil }
    }
}
