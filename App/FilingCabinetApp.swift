import AppIntents
import Core
import Foundation
import Screens
import SwiftUI

@main
struct FilingCabinetApp: App {
    @State private var startup: AppStartup
    @Environment(\.scenePhase) private var scenePhase
    /// Requests from outside the app. One per process, made here so it exists before any intent runs; it outlives a UI
    /// test's relaunch and Try again.
    private let requests: ExternalRequests

    init() {
        HeaderAppearance.install()
        let requests = ExternalRequests()
        self.requests = requests
        // Here, before any intent runs: the system launches the app cold to run one, and an unregistered dependency traps.
        AppDependencyManager.shared.add(dependency: requests)
        startup = AppStartup(arguments: CommandLine.arguments, requests: requests)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch startup.state {
                case .ready(let environment):
                    app(environment)
                        // A UI test's relaunch brings a new environment: every view is built again for it.
                        .id(ObjectIdentifier(environment))
                case .failed(let model):
                    // Never Home or Scan while the library can't open (#40).
                    LibraryFailureView(model: model)
                        .id(ObjectIdentifier(model))
                        // Dropped, not kept: a request must never act later, after a Try again that works.
                        .onChange(of: requests.pending, initial: true) { _, pending in
                            if pending != nil { _ = requests.take() }
                        }
                }
            }
            // Only a UI test's relaunch: anything else from outside the app is dropped while the library has failed.
            .onOpenURL { startup.relaunch(by: $0) }
        }
        .onChange(of: scenePhase) { _, phase in
            guard let environment = startup.environment else { return }
            switch phase {
            case .active:
                environment.enteredForeground()
                environment.lifecycle.sceneBecameActive()
                // Now, so the first frame after midnight doesn't show yesterday.
                environment.today.refresh()
                Task { await environment.becameActive() }
            case .background:
                // Leaving the app clears Home's cleanup banner (M4).
                environment.banner.clear()
                environment.leftForeground()
            case .inactive:
                environment.leftForeground()
            @unknown default:
                break
            }
        }
    }

    /// The app once the library is open.
    private func app(_ environment: AppEnvironment) -> some View {
        RootView(dependencies: environment.root, canScan: environment.isReady, requests: requests)
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
    }
}
