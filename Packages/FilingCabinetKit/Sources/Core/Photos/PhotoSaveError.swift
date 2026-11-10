/// Why Save to Photos didn't save.
public enum PhotoSaveError: Error, Sendable {
    /// The person turned add-only access off (or it is restricted): only Settings can turn it back on.
    case denied
    /// Photos couldn't add the pages.
    case failed
}
