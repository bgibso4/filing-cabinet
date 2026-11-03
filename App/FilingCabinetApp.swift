import Foundation
import Screens
import SwiftUI

@main
struct FilingCabinetApp: App {
    @State private var environment = AppEnvironment.make(arguments: CommandLine.arguments)
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: environment.root)
                .disabled(!environment.isReady)
                .task { await environment.launch() }
                .task {
                    // Midnight, a time zone change or a clock change: the system posts a day change (M5).
                    for await _ in NotificationCenter.default.notifications(named: .NSCalendarDayChanged) {
                        environment.today.refresh()
                    }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                environment.today.refresh()
                environment.lifecycle.sceneBecameActive()
            }
        }
    }
}
