import Foundation
import Screens
import SwiftUI

@main
struct FilingCabinetApp: App {
    @State private var environment = AppEnvironment.make(arguments: CommandLine.arguments)
    /// Bumped by a UI test's relaunch (`RelaunchURL`), so every view is built again for the new environment.
    @State private var generation = 0
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: environment.root, canScan: environment.isReady)
                .task { await environment.launch() }
                .task {
                    // Midnight, a time zone change or a clock change: the system posts a day change (M5).
                    for await _ in NotificationCenter.default.notifications(named: .NSCalendarDayChanged) {
                        environment.today.refresh()
                    }
                }
                .id(generation)
                .onOpenURL { url in
                    guard let relaunched = environment.relaunched(by: url) else { return }
                    environment = relaunched
                    generation += 1
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
