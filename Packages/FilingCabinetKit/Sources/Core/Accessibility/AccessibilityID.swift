/// Accessibility identifiers shared by the views and the UI tests. Views take identifiers from here, never from literals.
/// One nested enum per screen; a new screen adds its enum and one line to `all`.
public enum AccessibilityID {
    public enum Home {
        public static let scan = "home.scan"
        public static let recentRow = "home.recent"
        public static let allRow = "home.all"

        public static func collectionRow(_ collection: BuiltInCollection) -> String {
            "home.collection.\(collection.rawValue)"
        }

        public static var all: [String] {
            [scan, recentRow, allRow] + BuiltInCollection.allCases.map(collectionRow)
        }
    }

    public enum Save {
        /// The page in flight; a UI test checks that it is gone once the flight ends.
        public static let flight = "flight"
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

        public static var all: [String] {
            [back, header, page, strip]
        }
    }

    /// Every screen's identifiers, so a test can check they are unique across the app.
    public static var all: [String] {
        // The viewer's back button is the grid's: one system identifier, counted once.
        Home.all + Grid.all + Camera.all + CameraOff.all + Review.all + ExpiryDate.all
            + Viewer.all.filter { $0 != Viewer.back }
    }
}
