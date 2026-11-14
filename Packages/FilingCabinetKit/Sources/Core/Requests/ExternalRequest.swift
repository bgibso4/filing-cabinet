/// What the system asks the app to do from outside it: the Scan control, Shortcuts and Siri, or a Spotlight result.
public enum ExternalRequest: Equatable, Sendable {
    /// Open the camera.
    case scan
    /// Open Search with this text in the field.
    case search(String)
    /// Open this scan's viewer.
    case open(ScanID)
}
