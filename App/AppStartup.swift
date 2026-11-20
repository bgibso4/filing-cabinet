import Core
import Foundation
import Observation
import ScreenModels

#if DEBUG
    import TestSupport
#endif

/// Opens the library: the app (`ready`), or the screen that says the library couldn't open (`failed`, #40), whose Try
/// again opens it once more. Nothing falls back to an empty library. Also opens everything again for a UI test's
/// relaunch. `requests` outlives both: it is made once per process, before any intent can run.
@MainActor
@Observable
final class AppStartup {
    enum State {
        case ready(AppEnvironment)
        case failed(LibraryFailureModel)
    }

    private(set) var state: State

    /// The flags the library was opened with; Try again opens it with the same ones.
    @ObservationIgnored private var arguments: [String]
    /// The process's one sink: every environment sends through it, and the failure screen's events (with no
    /// environment, nothing else can send them).
    @ObservationIgnored private let analytics: any Analytics
    /// Requests from outside the app: the root acts on them, the failure screen drops them.
    let requests: ExternalRequests

    init(arguments: [String], requests: ExternalRequests) {
        let analytics = Self.makeAnalytics()
        self.arguments = arguments
        self.analytics = analytics
        self.requests = requests
        // Try again calls back into this startup, which can't be captured until `state` is set; it is filled in below,
        // before anyone can tap.
        weak var startup: AppStartup?
        state = Self.open(arguments: arguments, analytics: analytics) { startup?.retry() ?? false }
        startup = self
        sendLaunchRequest(arguments)
    }

    /// The app's collaborators once the library is open; nil while the failure screen shows.
    var environment: AppEnvironment? {
        guard case .ready(let environment) = state else { return nil }
        return environment
    }

    /// A UI test's next test in the running app (`RelaunchURL`): everything opened again from the URL's flags, so a
    /// relaunch whose library fails shows the failure screen. Does nothing unless this launch is a UI test's (so never
    /// in Release) and the URL relaunches with `-UITest`, which keeps the new one off the real library too.
    func relaunch(by url: URL) {
        guard Self.isUITest(arguments), let newArguments = RelaunchURL.arguments(from: url), Self.isUITest(newArguments)
        else { return }
        environment?.leftForeground()
        // `requests` outlives the relaunch: drop what the last test left untaken, so it can't act in the next one.
        _ = requests.take()
        arguments = newArguments
        state = Self.open(arguments: newArguments, analytics: analytics) { [weak self] in self?.retry() ?? false }
        sendLaunchRequest(newArguments)
    }

    /// A UI test's request from outside the app, sent to the running app (`RequestURL`) as the Scan control or Siri
    /// would send it after launch. Does nothing unless this launch is a UI test's, so never in Release.
    func request(by url: URL) {
        guard Self.isUITest(arguments) else { return }
        send(RequestURL.request(from: url))
    }

    /// Try again (the failure screen's model calls it): true, with the app ready, when the library opened.
    func retry() -> Bool {
        do throws(LibraryOpenFailure) {
            let environment = try AppEnvironment.make(arguments: arguments, isRetry: true, analytics: analytics)
            environment.lifecycle.launched()
            state = .ready(environment)
            return true
        } catch {
            analytics.send(.libraryOpenFailed)
            return false
        }
    }

    private static func open(arguments: [String], analytics: any Analytics, retry: @escaping () -> Bool) -> State {
        do throws(LibraryOpenFailure) {
            let environment = try AppEnvironment.make(arguments: arguments, analytics: analytics)
            environment.lifecycle.launched()
            return .ready(environment)
        } catch {
            analytics.send(.libraryOpenFailed)
            return .failed(LibraryFailureModel(error: error.underlying, analytics: analytics, retry: retry))
        }
    }

    /// TelemetryDeck in a Release build that has an app ID (#3); the log otherwise, so Debug builds (`make device`, UI
    /// tests) never reach the dashboard.
    private static func makeAnalytics() -> any Analytics {
        let appID = Bundle.main.object(forInfoDictionaryKey: "TelemetryDeckAppID") as? String
        switch AnalyticsSink.choose(isDebugBuild: AppEnvironment.isDebugBuild, appID: appID) {
        case .log: return LogAnalytics()
        case .telemetryDeck(let appID): return TelemetryDeckAnalytics(appID: appID)
        }
    }

    /// `-Request`: a UI test's request from outside the app, sent as an intent would send it (M15). `open:<n>` is the
    /// nth scan `-SeedScans` saves under `-UITest` (`LibrarySeed.scanID(at:)`), in the library once launch has seeded
    /// it; without `-UITest` seeded IDs are random, so it names no scan and is ignored. Try again
    /// sends nothing: the failure screen dropped the request.
    private func sendLaunchRequest(_ arguments: [String]) {
        send(LaunchOptions(arguments: arguments, isDebugBuild: AppEnvironment.isDebugBuild).request)
    }

    /// Sends what a `-Request` value names; `open:<n>` is the nth seeded scan.
    private func send(_ request: RequestFlag?) {
        #if DEBUG
            switch request {
            case .scan: requests.send(.scan)
            case .search(let text): requests.send(.search(text))
            case .open(let seeded): requests.send(.open(LibrarySeed.scanID(at: seeded - 1)))
            case .trash: requests.send(.trash)
            case nil: break
            }
        #endif
    }

    private static func isUITest(_ arguments: [String]) -> Bool {
        LaunchOptions(arguments: arguments, isDebugBuild: AppEnvironment.isDebugBuild).isUITest
    }
}
