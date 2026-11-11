/// How scans left the app.
public enum ExportKind: String, CaseIterable, AnalyticsToken {
    case share
    case photos
    case files
    case copyText
}
