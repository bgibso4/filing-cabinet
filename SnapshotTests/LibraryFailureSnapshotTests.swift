import Foundation
import ScreenModels
import Screens
import TestSupport
import XCTest

/// The screen shown instead of the app when the library can't open (#40): the B1 icon (error-icon-v2.html) in the
/// welcome screens' layout (settings-and-error.html), light, dark and at the largest text. There is no `design/`
/// screen for it.
final class LibraryFailureSnapshotTests: XCTestCase {
    @MainActor
    func testLibraryFailure() throws {
        let model = LibraryFailureModel(
            error: CocoaError(.fileReadCorruptFile), analytics: RecordingAnalytics(), retry: { false })
        try SnapshotHost.assertScreen(LibraryFailureView(model: model), testName: "library_failure")
    }
}
