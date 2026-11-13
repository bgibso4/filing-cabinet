/// Accessibility identifiers shared by the views and the UI tests. Views take identifiers from here, never from literals.
/// One nested enum per screen; a new screen adds its enum and one line to `all`.
public enum AccessibilityID {
    public enum Home {
        public static let scan = "home.scan"
        /// Favorites in the views card (B16), after Recent, whenever the card shows.
        public static let favoritesRow = "home.favorites"
        public static let recentRow = "home.recent"
        public static let allRow = "home.all"
        /// Only while the views card shows, or while something is in Trash.
        public static let trashRow = "home.trash"
        /// The gear in the bar, on the row above the large title (B9).
        public static let settings = "home.settings"
        /// "4 scans moved to Trash · View", only after a cleanup the person heard nothing about.
        public static let cleanupBanner = "home.cleanupBanner"
        /// "Favorites ›" over the Favorites row, only with a favourite (B15), so not in `all`.
        public static let favoritesLink = "home.favoritesLink"
        /// Every Favorites card's identifier starts with this; cards are checked by prefix, not listed in `all`.
        public static let favoritePrefix = "home.favorite."
        /// The drawn search field under the title (02-01): it opens Search.
        public static let search = "home.search"

        public static func collectionRow(_ collection: BuiltInCollection) -> String {
            "home.collection.\(collection.rawValue)"
        }

        public static func favorite(_ id: ScanID) -> String {
            favoritePrefix + id.uuid.uuidString
        }

        public static var all: [String] {
            [scan, favoritesRow, recentRow, allRow, trashRow, settings, cleanupBanner, search]
                + BuiltInCollection.allCases.map(collectionRow)
        }
    }

    public enum Grid {
        /// The system back button (the grid keeps the navigation bar so swipe back works). SwiftUI can't set its
        /// identifier, so this is the one UIKit gives it.
        public static let back = "BackButton"
        public static let scan = "grid.scan"
        /// Select, or Cancel while selecting; always there, greyed out while the grid is empty (#68).
        public static let select = "grid.select"
        /// Only while selecting, in Scan's place.
        public static let moveToTrash = "grid.moveToTrash"
        /// Only while selecting, leading: shares the selection as PDFs (B12).
        public static let share = "grid.share"
        /// Only while selecting, trailing: Favorite or Remove from Favorites for the selection (B12).
        public static let favorite = "grid.favorite"
        /// Every tile's identifier starts with this; tiles are checked by prefix, not listed in `all`.
        public static let tilePrefix = "grid.tile."

        public static func tile(_ id: ScanID) -> String {
            tilePrefix + id.uuid.uuidString
        }

        /// What a grid with scans shows when not selecting.
        public static var all: [String] {
            [back, scan, select]
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
        /// The sheet's Save, or the card's.
        public static let save = "review.save"
        /// Only with more than one page, so not in `all`.
        public static let strip = "review.strip"
        /// The suggestion card's title and collection, which open the sheet. Only while the card shows, so not in `all`.
        public static let card = "review.card"

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
        /// The heart, left of Info in the centre pill (06-01).
        public static let favorite = "viewer.favorite"
        public static let trash = "viewer.trash"
        /// Share, at the bar's leading edge (06-01).
        public static let share = "viewer.share"
        /// The "•••" at the top's trailing edge, which opens More (06-03).
        public static let more = "viewer.more"

        public static var all: [String] {
            [back, header, page, strip, details, favorite, trash, share, more]
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
        /// Select, or Cancel while selecting; always there, greyed out while Trash is empty (B14).
        public static let select = "trash.select"
        /// How long scans stay, above the tiles; not while Trash is empty (E8).
        public static let notice = "trash.notice"
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
            [select, notice, emptyTrash, deleteSelected, restoreSelected]
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
        public static let appearance = "settings.appearance"
        public static let notifications = "settings.notifications"
        public static let intelligence = "settings.intelligence"
        public static let feedback = "settings.feedback"
        public static let privacy = "settings.privacy"

        public static var all: [String] {
            [collections, appearance, intelligence, notifications, feedback, privacy]
        }
    }

    /// The "No mail app" alert, from Send feedback and (Plan 6) the failure screen's Send report.
    public enum Feedback {
        public static let noMailAlert = "feedback.noMailAlert"
        public static let copy = "feedback.copy"

        public static var all: [String] { [noMailAlert, copy] }
    }

    /// The screen shown when the library can't open (#40).
    public enum LibraryFailure {
        public static let title = "libraryFailure.title"
        public static let sendReport = "libraryFailure.sendReport"
        public static let tryAgain = "libraryFailure.tryAgain"

        public static var all: [String] { [title, sendReport, tryAgain] }
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

    /// Search, pushed from Home's field (08-01…08-06).
    public enum Search {
        public static let field = "search.field"
        /// The X beside the field: back to Home.
        public static let close = "search.close"
        /// The field's own clear button, only while it holds text (08-03).
        public static let clearQuery = "search.clearQuery"
        /// Recent searches' Clear, only while there are some (08-02).
        public static let clear = "search.clear"
        /// "Search all scans", only when the chosen collection has nothing and others have (08-05).
        public static let searchAll = "search.searchAll"
        /// Every result row's identifier starts with this; rows are checked by prefix, not listed in `all`.
        public static let resultPrefix = "search.result."
        /// Every recently viewed scan's identifier starts with this.
        public static let viewedPrefix = "search.viewed."
        /// Every recent search's identifier starts with this, then its place in the list (0 is the newest).
        public static let recentPrefix = "search.recent."

        /// A filter chip: All for nil, otherwise the collection.
        public static func chip(_ collection: BuiltInCollection?) -> String {
            "search.chip.\(collection?.rawValue ?? "all")"
        }

        public static func result(_ id: ScanID) -> String {
            resultPrefix + id.uuid.uuidString
        }

        public static func viewed(_ id: ScanID) -> String {
            viewedPrefix + id.uuid.uuidString
        }

        public static func recent(_ index: Int) -> String {
            recentPrefix + String(index)
        }

        /// What Search always shows: the field, the X and every chip.
        public static var all: [String] {
            [field, close, chip(nil)] + BuiltInCollection.allCases.map(chip)
        }
    }

    /// A page pill's title line, inside the pill's combined element: the audit reports it on its own.
    public static func pillTitle(_ pill: String) -> String { "\(pill).title" }

    /// Every screen's identifiers, so a test can check they are unique across the app.
    public static var all: [String] {
        // The viewer's back button is the grid's: one system identifier, counted once.
        Home.all + [Home.favoritesLink] + Grid.all + Camera.all + CameraOff.all + Review.all + [Review.strip]
            + ExpiryDate.all
            + Viewer.all.filter { $0 != Viewer.back } + Details.all + [
                Details.clearTitle, Details.titleText, Details.scannedLine,
            ] + Trash.all + TrashViewer.all + Settings.all + Feedback.all + Collections.all + CollectionSettings.all
            + Search.all + [Search.clearQuery, Search.clear, Search.searchAll] + LibraryFailure.all
    }
}
