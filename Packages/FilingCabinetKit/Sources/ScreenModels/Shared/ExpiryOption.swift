import Core

/// One choice in the expiry menu Review and Details share: "Receipts default · Jan 9, 2027", "1 week · Oct 18",
/// "1 week · Oct 7 · passed", "Forever · Never expires".
package struct ExpiryOption {
    package let label: String
    /// The until-date the choice gives, "Oct 7 · passed", or "Never expires".
    package let detail: String
    /// What choosing it stores; nil is the collection default.
    package let override: ExpiryOverride?
    package let isSelected: Bool
    /// Its last day is behind today, so it can't be chosen: choosing it would send the scan to Trash (M15).
    package let isPassed: Bool
}
