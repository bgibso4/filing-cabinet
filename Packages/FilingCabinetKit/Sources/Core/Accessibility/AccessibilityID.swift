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

    /// Every screen's identifiers, so a test can check they are unique across the app.
    public static var all: [String] {
        Home.all + Grid.all + Camera.all + CameraOff.all
    }
}
