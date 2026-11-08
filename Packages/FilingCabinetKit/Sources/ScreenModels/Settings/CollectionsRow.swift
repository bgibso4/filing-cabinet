import Core

/// One collection on the Collections screen (10-02): "Kept 3 months · 23 scans".
package struct CollectionsRow: Equatable {
    package let collection: BuiltInCollection
    package let name: String
    package let detail: String
}
