import Core

/// What a finished save hands back: the new scan's id and the VoiceOver announcement for it (M11).
public struct SavedScan: Equatable {
    package let id: ScanID
    /// "Saved to Receipts".
    package let announcement: String
}
