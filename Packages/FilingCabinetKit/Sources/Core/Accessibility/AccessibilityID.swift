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

    public enum Grid {
        public static let header = "grid.header"

        public static var all: [String] {
            [header]
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
        public static let openSettings = "cameraOff.openSettings"
        public static let close = "cameraOff.close"

        public static var all: [String] {
            [openSettings, close]
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

    /// Every screen's identifiers, so a test can check they are unique across the app.
    public static var all: [String] {
        Home.all + Grid.all + Camera.all + CameraOff.all + Review.all + ExpiryDate.all
    }
}
