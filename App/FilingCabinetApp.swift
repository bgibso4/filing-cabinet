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
                .task { await environment.notifier.run() }
                .task {
                    // Midnight or a clock change: the system posts a day change (M5), and notes are planned again.
                    for await _ in NotificationCenter.default.notifications(named: .NSCalendarDayChanged) {
                        environment.today.refresh()
                        environment.notifier.reschedule()
                    }
                }
                .task {
                    // A time zone change can move today, and the day each scan enters Trash even when today stays;
                    // the day change isn't documented to come then, so this plans again on its own.
                    for await _ in NotificationCenter.default.notifications(named: .NSSystemTimeZoneDidChange) {
                        environment.today.refresh()
                        environment.notifier.reschedule()
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
            switch phase {
            case .active:
                environment.lifecycle.sceneBecameActive()
                // Now, so the first frame after midnight doesn't show yesterday.
                environment.today.refresh()
                Task { await environment.becameActive() }
            case .background:
                // Leaving the app clears Home's cleanup banner (M4).
                environment.banner.clear()
            default:
                break
            }
        }
    }
}
