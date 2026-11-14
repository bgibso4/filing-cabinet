/// `-FailLibraryOpen [once]`: opening the library fails, so the failure screen shows (#40).
public enum FailLibraryOpen: Sendable, Equatable {
    /// Every attempt fails, Try again included.
    case always
    /// Only the first attempt fails, so Try again opens the library.
    case once
}
