/// Where a scan was started from.
public enum ScanSource: String, CaseIterable, AnalyticsToken {
    case home
    case grid
}

/// Which screen a scan was cancelled from.
public enum CancelStage: String, CaseIterable, AnalyticsToken {
    case camera
    case review
}

/// Why a save failed.
public enum FailureReason: String, CaseIterable, AnalyticsToken {
    case diskFull
    case writeFailed
}
