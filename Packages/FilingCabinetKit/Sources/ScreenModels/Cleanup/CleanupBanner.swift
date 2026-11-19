import Core
import Foundation
import Library
import Observation

/// Home's line after a cleanup (02-04, M4): how many scans moved to Trash on their own since the person last saw
/// it. It shows whether or not notes are on (#110): a note can fail to arrive, and then this is the only word of it.
/// Viewing Trash or leaving the app clears it.
@Observable
public final class CleanupBanner {
    @ObservationIgnored private let library: any ScanLibrary
    @ObservationIgnored private let today: Today
    @ObservationIgnored private let preferences: AppPreferences

    /// The first run (no stored day) starts counting today, so the scans already in Trash are not reported.
    public init(library: any ScanLibrary, today: Today, preferences: AppPreferences) {
        self.library = library
        self.today = today
        self.preferences = preferences
        if preferences.cleanupSeenThrough == nil { preferences.cleanupSeenThrough = today.day }
    }

    /// "4 scans moved to Trash", or nil when there is nothing new.
    package var text: String? {
        guard let seenThrough = preferences.cleanupSeenThrough else { return nil }
        let day = today.day
        let count = library.scans.count { scan in
            // A stored Trash day means the person (or a change they made) sent it there: no news.
            guard scan.trashedDay == nil,
                case .trash(_, let entered) = scan.place(lifespans: library.lifespans, today: day, in: today.calendar)
            else { return false }
            return entered > seenThrough
        }
        guard count > 0 else { return nil }
        return String(localized: "\(count) scans moved to Trash", bundle: #bundle)
    }

    /// Everything up to today has been seen.
    public func clear() {
        preferences.cleanupSeenThrough = today.day
    }
}
