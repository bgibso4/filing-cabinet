import Core

/// One choice in Review's expiry menu: "Receipts default · Jan 9, 2027", "1 week · Oct 18", "Forever · Never expires".
package struct ExpiryOption {
    package let label: String
    /// The until-date the choice gives, or "Never expires".
    package let detail: String
    /// What choosing it stores; nil is the collection default.
    package let override: ExpiryOverride?
    package let isSelected: Bool
}
