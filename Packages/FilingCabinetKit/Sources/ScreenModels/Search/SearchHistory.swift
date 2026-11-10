import Core
import Foundation
import Observation

/// Recent searches and recently viewed scans, kept on this phone in `UserDefaults` (M4): history, not documents.
@MainActor
@Observable
public final class SearchHistory {
    /// The last 3 searches kept (M5), newest first, trimmed, without repeats (ignoring case).
    package private(set) var recentSearches: [String] {
        didSet { defaults.set(recentSearches, forKey: Key.recentSearches) }
    }

    /// The last 8 scans opened in the viewer from the library, newest first. Some may be in Trash or gone since.
    package private(set) var recentlyViewed: [ScanID] {
        didSet { defaults.set(recentlyViewed.map(\.uuid.uuidString), forKey: Key.recentlyViewed) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
        recentSearches = defaults.stringArray(forKey: Key.recentSearches) ?? []
        recentlyViewed = (defaults.stringArray(forKey: Key.recentlyViewed) ?? []).compactMap {
            UUID(uuidString: $0).map(ScanID.init(uuid:))
        }
    }

    /// Keeps a search, first; an empty one is skipped and a repeat moves up.
    package func record(search: String) {
        let search = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !search.isEmpty else { return }
        let others = recentSearches.filter { $0.caseInsensitiveCompare(search) != .orderedSame }
        recentSearches = Array(([search] + others).prefix(Self.searchesKept))
    }

    /// Recent searches' Clear: recently viewed stays.
    package func clearSearches() {
        recentSearches = []
    }

    /// Keeps a scan opened in the viewer, first; a repeat moves up.
    package func record(viewed id: ScanID) {
        recentlyViewed = Array(([id] + recentlyViewed.filter { $0 != id }).prefix(Self.viewedKept))
    }

    // M4: three recent searches, eight recently viewed scans.
    private static let searchesKept = 3
    private static let viewedKept = 8

    private enum Key {
        static let recentSearches = "recentSearches"
        static let recentlyViewed = "recentlyViewed"
    }
}
