/// How many scans an event touched or found, without the exact number (M19): 0, 1, 2–5 or 6 and more.
package enum CountBucket: String, CaseIterable, AnalyticsToken {
    case none
    case one
    case fewer
    case many

    package init(_ count: Int) {
        switch count {
        case ..<1: self = .none
        case 1: self = .one
        case 2...5: self = .fewer
        default: self = .many
        }
    }
}

/// How scans left the app.
public enum ExportKind: String, CaseIterable, AnalyticsToken {
    case share
    case photos
    case files
    case copyText
}
