import Core
import Foundation
import TestSupport
import Testing
import UIKit

@testable import FilingCabinet

/// Opening the library at launch, in the app's process (#40): the app when it opens, the failure screen when it
/// doesn't, and Try again.
@MainActor
@Suite(.serialized)
struct AppStartupTests {
    /// `-UITest` turns animations off for the process; the snapshot tests that follow keep theirs.
    private func startup(_ flags: [String], requests: ExternalRequests = ExternalRequests()) -> AppStartup {
        let animations = UIView.areAnimationsEnabled
        defer { UIView.setAnimationsEnabled(animations) }
        return AppStartup(arguments: ["-UITest", "-Notifications", "authorized"] + flags, requests: requests)
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

    @Test func requestFlagIsSentAtLaunch() {
        let requests = ExternalRequests()
        _ = startup(["-Request", "search:lease"], requests: requests)
        #expect(requests.pending == .search("lease"))
    }

    @Test func openRequestNamesTheNthSeededScan() {
        let requests = ExternalRequests()
        _ = startup(["-SeedScans", "3", "-Request", "open:2"], requests: requests)
        #expect(requests.pending == .open(LibrarySeed.scanID(at: 1)))
    }

    @Test func tryAgainSendsTheRequestNoMore() {
        let requests = ExternalRequests()
        let startup = startup(["-FailLibraryOpen", "once", "-Request", "scan"], requests: requests)
        // What the failure screen does with it.
        _ = requests.take()
        let animations = UIView.areAnimationsEnabled
        defer { UIView.setAnimationsEnabled(animations) }
        #expect(startup.retry())
        #expect(requests.pending == nil)
    }

    /// A UI test's relaunch starts the next test: a request the last one left untaken doesn't carry over.
    @Test func relaunchDropsTheUntakenRequest() throws {
        let requests = ExternalRequests()
        let startup = startup(["-Request", "scan"], requests: requests)
        let url = try #require(RelaunchURL.make(arguments: ["-UITest", "-Notifications", "authorized"]))
        let animations = UIView.areAnimationsEnabled
        defer { UIView.setAnimationsEnabled(animations) }
        startup.relaunch(by: url)
        #expect(requests.pending == nil)
    }
}
