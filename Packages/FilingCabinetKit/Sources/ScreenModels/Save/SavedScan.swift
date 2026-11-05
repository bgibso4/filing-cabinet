import Core

/// What a finished save hands back: enough for the save flight and its VoiceOver announcement (M11).
public struct SavedScan: Equatable {
    package let id: ScanID
    package let collection: BuiltInCollection
    package let source: ScanSource
    package let preselected: BuiltInCollection?
    /// "Saved to Receipts".
    package let announcement: String
}
