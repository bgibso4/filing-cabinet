import Screens
import SwiftUI

@main
struct FilingCabinetApp: App {
    @State private var environment = AppEnvironment.make(arguments: CommandLine.arguments)
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView(model: environment.home, onScan: {})
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                environment.lifecycle.sceneBecameActive()
            }
        }
    }
}
