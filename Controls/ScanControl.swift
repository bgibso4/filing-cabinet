import AppIntents
import SwiftUI
import WidgetKit

/// The Scan control for Control Center, the Lock Screen and the Action button (Plan 6 §7, 11-05, 11-06). It runs
/// `ScanDocumentIntent`, which opens the app at the camera.
struct ScanControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.cadre.filingcabinet.scan") {
            ControlWidgetButton(action: ScanDocumentIntent()) {
                Label("Scan", systemImage: "doc.viewfinder")
            }
        }
        .displayName("Scan")
        .description("Opens the camera in Filing Cabinet.")
    }
}
