import Foundation
import Testing

@testable import Core

@Test(arguments: [
    ("scan", RequestFlag.scan), ("search:city pharmacy", .search("city pharmacy")), ("open:2", .open(seeded: 2)),
])
func aRequestSurvivesTheRoundTrip(value: String, request: RequestFlag) throws {
    let url = try #require(RequestURL.make(value))
    #expect(url.scheme == RelaunchURL.scheme)
    #expect(RequestURL.request(from: url) == request)
}

@Test func otherURLsCarryNoRequest() throws {
    let relaunch = try #require(RelaunchURL.make(arguments: ["-UITest", "-Request", "scan"]))
    #expect(RequestURL.request(from: relaunch) == nil)
    for text in [
        "https://example.com/request?value=scan", "filingcabinet-uitest://request",
        "filingcabinet-uitest://request?value=nonsense",
    ] {
        let url = try #require(URL(string: text))
        #expect(RequestURL.request(from: url) == nil, "\(text)")
    }
}

@Test func aRequestURLIsNotARelaunch() throws {
    let url = try #require(RequestURL.make("scan"))
    #expect(RelaunchURL.arguments(from: url) == nil)
}
