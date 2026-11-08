/// Accessibility identifiers shared by the views and the UI tests. Views take identifiers from here, never from literals.
/// One nested enum per screen; a new screen adds its enum and one line to `all`.
public enum AccessibilityID {
    public enum Home {
        public static let scan = "home.scan"
        public static let recentRow = "home.recent"
        public static let allRow = "home.all"
        /// Only while the views card shows, or while something is in Trash.
        public static let trashRow = "home.trash"
        /// The gear beside the title.
        public static let settings = "home.settings"

        public static func collectionRow(_ collection: BuiltInCollection) -> String {
            "home.collection.\(collection.rawValue)"
        }

        public static var all: [String] {
            [scan, recentRow, allRow, trashRow, settings] + BuiltInCollection.allCases.map(collectionRow)
        }
    }

    public enum Grid {
        /// The system back button (the grid keeps the navigation bar so swipe back works). SwiftUI can't set its
        /// identifier, so this is the one UIKit gives it.
        public static let back = "BackButton"
        public static let header = "grid.header"
        public static let scan = "grid.scan"
        /// Every tile's identifier starts with this; tiles are checked by prefix, not listed in `all`.
        public static let tilePrefix = "grid.tile."

        public static func tile(_ id: ScanID) -> String {
            tilePrefix + id.uuid.uuidString
        }

        public static var all: [String] {
            [back, header, scan]
        }
    }

    /// The fake camera UI tests use in place of VisionKit's (M16).
    public enum Camera {
        public static let fakeFinish = "camera.fakeFinish"
        public static let fakeCancel = "camera.fakeCancel"

        public static var all: [String] {
            [fakeFinish, fakeCancel]
        }
    }

    public enum CameraOff {
        public static let title = "cameraOff.title"
        public static let message = "cameraOff.message"
        public static let openSettings = "cameraOff.openSettings"
        public static let close = "cameraOff.close"

        public static var all: [String] {
            [title, message, openSettings, close]
        }
    }

    /// The review after the camera (option G's sheet).
    public enum Review {
        public static let close = "review.close"
        public static let rescan = "review.rescan"
        public static let pagePill = "review.pagePill"
        /// The title row: the field and its pencil.
        public static let title = "review.title"
        public static let titleField = "review.titleField"
        public static let collection = "review.collection"
        public static let expiry = "review.expiry"
        public static let save = "review.save"
        /// Only with more than one page, so not in `all`.
        public static let strip = "review.strip"

        public static var all: [String] {
            [close, rescan, pagePill, title, titleField, collection, expiry, save]
        }
    }

    /// The sheet behind the expiry menu's "Choose a date…".
    public enum ExpiryDate {
        public static let picker = "expiryDate.picker"
        public static let cancel = "expiryDate.cancel"
        public static let done = "expiryDate.done"

        public static var all: [String] {
            [picker, cancel, done]
        }
    }

    public enum Viewer {
        /// The system back button, as on the grid.
        public static let back = Grid.back
        public static let header = "viewer.header"
        public static let page = "viewer.page"
        public static let strip = "viewer.strip"
        /// The bottom bar's Info button, which opens Details as the header pill does.
        public static let details = "viewer.details"
        public static let trash = "viewer.trash"

        public static var all: [String] {
            [back, header, page, strip, details, trash]
        }
    }

    /// The Details sheet over the viewer.
    public enum Details {
        public static let sheet = "details.sheet"
        /// The title and its pencil: tapping it renames.
        public static let title = "details.title"
        public static let titleField = "details.titleField"
        /// Only while renaming, so not in `all`.
        public static let clearTitle = "details.clearTitle"
        public static let collection = "details.collection"
        public static let expiry = "details.expiry"
        /// Only after a move, with its note.
        public static let undo = "details.undo"
        /// The sheet's text the accessibility audit reports on its own: the title inside its button and the scanned
        /// line.
        public static let titleText = "details.titleText"
        public static let scannedLine = "details.scannedLine"

        public static var all: [String] {
            [sheet, title, titleField, collection, expiry, undo]
        }
    }

    public enum Trash {
        public static let header = "trash.header"
        /// Select, or Cancel while selecting; not while Trash is empty.
        public static let select = "trash.select"
        /// Only while not selecting and Trash has scans.
        public static let emptyTrash = "trash.emptyTrash"
        /// Only while selecting.
        public static let deleteSelected = "trash.deleteSelected"
        public static let restoreSelected = "trash.restoreSelected"
        /// Every tile's identifier starts with this; tiles are checked by prefix, not listed in `all`.
        public static let tilePrefix = "trash.tile."

        public static func tile(_ id: ScanID) -> String {
            tilePrefix + id.uuid.uuidString
        }

        public static var all: [String] {
            [header, select, emptyTrash, deleteSelected, restoreSelected]
        }
    }

    /// A scan opened from Trash (09-04). Its pages and strip are the viewer's.
    public enum TrashViewer {
        public static let close = "trashViewer.close"
        public static let header = "trashViewer.header"
        public static let deleteNow = "trashViewer.deleteNow"
        public static let restore = "trashViewer.restore"

        public static var all: [String] {
            [close, header, deleteNow, restore]
        }
    }

    /// Settings from Home's gear (10-01).
    public enum Settings {
        public static let collections = "settings.collections"
        public static let notifications = "settings.notifications"

        public static var all: [String] {
            [collections, notifications]
        }
    }

    /// Settings › Collections (10-02): one row per collection.
    public enum Collections {
        public static func row(_ collection: BuiltInCollection) -> String {
            "collections.\(collection.rawValue)"
        }

        public static var all: [String] {
            BuiltInCollection.allCases.map(row)
        }
    }

    /// One collection's settings (10-03).
    public enum CollectionSettings {
        public static let keepScansFor = "collectionSettings.keepScansFor"

        public static var all: [String] {
            [keepScansFor]
        }
    }

    /// A page pill's title line, inside the pill's combined element: the audit reports it on its own.
    public static func pillTitle(_ pill: String) -> String { "\(pill).title" }

    /// Every screen's identifiers, so a test can check they are unique across the app.
    public static var all: [String] {
        // The viewer's back button is the grid's: one system identifier, counted once.
        Home.all + Grid.all + Camera.all + CameraOff.all + Review.all + [Review.strip] + ExpiryDate.all
            + Viewer.all.filter { $0 != Viewer.back } + Details.all + [
                Details.clearTitle, Details.titleText, Details.scannedLine,
            ] + Trash.all + TrashViewer.all + Settings.all + Collections.all + CollectionSettings.all
    }
}
