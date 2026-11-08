/// Whether iOS lets the app post notifications. The raw values are the `-Notifications` launch flag's.
public enum NotificationAuthorization: String, Sendable {
    case authorized
    case denied
    case notDetermined
}
