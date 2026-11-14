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
    /// The failure screen's events: with no environment, nothing else can send them.
    @ObservationIgnored private let analytics: any Analytics
    /// Requests from outside the app: the root acts on them, the failure screen drops them.
    let requests: ExternalRequests

    init(arguments: [String], requests: ExternalRequests) {
        let analytics = LogAnalytics()
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

    /// Try again (the failure screen's model calls it): true, with the app ready, when the library opened.
    func retry() -> Bool {
        do throws(LibraryOpenFailure) {
            state = .ready(try AppEnvironment.make(arguments: arguments, isRetry: true))
            return true
        } catch {
            analytics.send(.libraryOpenFailed)
            return false
        }
    }

    private static func open(arguments: [String], analytics: any Analytics, retry: @escaping () -> Bool) -> State {
        do throws(LibraryOpenFailure) {
            return .ready(try AppEnvironment.make(arguments: arguments))
        } catch {
            analytics.send(.libraryOpenFailed)
            return .failed(LibraryFailureModel(error: error.underlying, analytics: analytics, retry: retry))
        }
    }

    /// `-Request`: a UI test's request from outside the app, sent as an intent would send it (M15). `open:<n>` is the
    /// nth scan `-SeedScans` saves under `-UITest` (`LibrarySeed.scanID(at:)`), in the library once launch has seeded
    /// it; without `-UITest` seeded IDs are random, so it names no scan and is ignored. Try again
    /// sends nothing: the failure screen dropped the request.
    private func sendLaunchRequest(_ arguments: [String]) {
        #if DEBUG
            switch LaunchOptions(arguments: arguments, isDebugBuild: AppEnvironment.isDebugBuild).request {
            case .scan: requests.send(.scan)
            case .search(let text): requests.send(.search(text))
            case .open(let seeded): requests.send(.open(LibrarySeed.scanID(at: seeded - 1)))
            case nil: break
            }
        #endif
    }

    private static func isUITest(_ arguments: [String]) -> Bool {
        LaunchOptions(arguments: arguments, isDebugBuild: AppEnvironment.isDebugBuild).isUITest
    }
}
