import Core

/// One row of Review's collection menu: "Receipts", "3 months".
package struct CollectionOption {
    package let collection: BuiltInCollection
    package let name: String
    /// "Kept forever", "3 months", "1 week".
    package let lifespan: String
}
