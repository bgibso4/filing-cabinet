/// Which part of a scan Details changed.
public enum EditedField: String, CaseIterable, AnalyticsToken {
    case title
    case collection
    case expiry
}
