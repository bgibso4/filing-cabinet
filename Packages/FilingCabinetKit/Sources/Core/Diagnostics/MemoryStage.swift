/// The points of a scan where a debug build records the app's memory (#50). The raw value is the name in the file.
public enum MemoryStage: String, Sendable {
    case appOpened = "app opened"
    /// The camera handed its pages to the app.
    case cameraFinished = "camera finished"
    /// Reading the pages finished.
    case reviewReady = "review ready"
    case saved
    case viewerClosed = "viewer closed"
    case background = "app in background"
}
