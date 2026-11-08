import Screens
import SwiftUI
import XCTest

final class CameraOffSnapshotTests: XCTestCase {
    /// The system draws a presented sheet's chrome, which a snapshot can't capture, so this reproduces it: the compact
    /// sheet's rounded surface at the bottom of the screen, inset from the screen edges (Home.dc.html line 288). The sheet
    /// draws its own grabber. The dimmed Home behind it is left out.
    private struct SheetChrome: View {
        private static let inset: CGFloat = 8
        private static let cornerRadius: CGFloat = 34

        /// Screens' resource bundle, where the token colours live.
        let screensBundle: Bundle

        var body: some View {
            CameraOffSheet(onOpenSettings: {}, onClose: {})
                .background(Color("bg-surface", bundle: screensBundle))
                .clipShape(.rect(cornerRadius: Self.cornerRadius))
                .padding([.horizontal, .bottom], Self.inset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .background(Color("bg-grouped", bundle: screensBundle))
                .ignoresSafeArea(edges: .bottom)
        }
    }

    @MainActor
    func testCameraOff() throws {
        // Screens' resources are a bundle inside the host app.
        let url = Bundle.main.url(forResource: "FilingCabinetKit_Screens", withExtension: "bundle")
        let bundle = try XCTUnwrap(url.flatMap(Bundle.init(url:)))
        try SnapshotHost.assertScreen(SheetChrome(screensBundle: bundle), testName: "camera_off")
    }
}
