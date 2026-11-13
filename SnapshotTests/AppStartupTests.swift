import Foundation
import Testing
import UIKit

@testable import FilingCabinet

/// Opening the library at launch, in the app's process (#40): the app when it opens, the failure screen when it
/// doesn't, and Try again.
@MainActor
@Suite(.serialized)
struct AppStartupTests {
    /// `-UITest` turns animations off for the process; the snapshot tests that follow keep theirs.
    private func startup(_ flags: [String]) -> AppStartup {
        let animations = UIView.areAnimationsEnabled
        defer { UIView.setAnimationsEnabled(animations) }
        return AppStartup(arguments: ["-UITest", "-Notifications", "authorized"] + flags)
    }

    private func isFailed(_ startup: AppStartup) -> Bool {
        if case .failed = startup.state { return true }
        return false
    }

    @Test func opensTheApp() {
        let startup = startup([])
        #expect(startup.environment != nil)
    }

    @Test func failedOpenShowsTheFailureScreen() {
        let startup = startup(["-FailLibraryOpen"])
        #expect(isFailed(startup))
        #expect(startup.environment == nil)
    }

    @Test func tryAgainThatStillFailsKeepsTheScreen() {
        let startup = startup(["-FailLibraryOpen"])
        #expect(!startup.retry())
        #expect(isFailed(startup))
    }

    @Test func tryAgainOpensTheAppWhenTheLibraryOpens() {
        let startup = startup(["-FailLibraryOpen", "once"])
        #expect(isFailed(startup))
        let animations = UIView.areAnimationsEnabled
        defer { UIView.setAnimationsEnabled(animations) }
        #expect(startup.retry())
        #expect(startup.environment != nil)
    }
}
