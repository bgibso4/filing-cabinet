import Core
import Foundation

/// What iPhone search knows about one scan: its title, "Receipts · 3 pages" and page 1's thumbnail. Titles only: never
/// the scan's text or search words (A10).
public struct SpotlightItem: Equatable, Sendable {
    package let id: ScanID
    package let title: String
    /// "Receipts · 3 pages", made by the caller.
    package let detail: String
    /// Page 1's cached JPEG; nil when it isn't cached.
    package let thumbnail: Data?
    /// When the scan enters Trash on its own, so search drops it even if the app isn't opened then; nil when it is
    /// kept forever.
    package let expires: Date?

    package init(id: ScanID, title: String, detail: String, thumbnail: Data?, expires: Date?) {
        self.id = id
        self.title = title
        self.detail = detail
        self.thumbnail = thumbnail
        self.expires = expires
    }
}

extension ScanID {
    /// The scan's identifier in Spotlight.
    package var spotlightIdentifier: String { uuid.uuidString }

    /// The scan a Spotlight result names; nil for anything that isn't one of ours.
    public init?(spotlightIdentifier: String) {
        guard let uuid = UUID(uuidString: spotlightIdentifier) else { return nil }
        self.init(uuid: uuid)
    }
}
