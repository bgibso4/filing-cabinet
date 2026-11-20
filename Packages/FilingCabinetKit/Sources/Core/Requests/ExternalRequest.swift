/// What the system asks the app to do from outside it: the Scan control, Shortcuts and Siri, a Spotlight result, or a
/// tapped cleanup note.
public enum ExternalRequest: Equatable, Sendable {
    /// Open the camera.
    case scan
    /// Open Search with this text in the field.
    case search(String)
    /// Open this scan's viewer.
    case open(ScanID)
    /// Open Trash, where a cleanup note's scans are.
    case trash
}
