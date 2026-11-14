import Testing

@testable import Core

@Test func debugAlwaysLogs() {
    #expect(AnalyticsSink.choose(isDebugBuild: true, appID: "ABC") == .log)
}

@Test func blankIDLogs() {
    for appID: String? in [nil, "", "  "] {
        #expect(AnalyticsSink.choose(isDebugBuild: false, appID: appID) == .log)
    }
}

@Test func releaseWithIDSends() {
    #expect(AnalyticsSink.choose(isDebugBuild: false, appID: " ABC ") == .telemetryDeck(appID: "ABC"))
}
