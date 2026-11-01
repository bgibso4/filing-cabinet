/// Accessibility identifiers shared by the views and the UI tests. Views take identifiers from here, never from literals.
public enum AccessibilityID {
    public static let scanButton = "home.scan"

    public static func collectionRow(_ collection: BuiltInCollection) -> String {
        "home.collection.\(collection.rawValue)"
    }

    /// Every identifier, so a test can check they are unique.
    public static var all: [String] {
        [scanButton] + BuiltInCollection.allCases.map(collectionRow)
    }
}
