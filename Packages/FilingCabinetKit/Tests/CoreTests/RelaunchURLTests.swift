import Foundation
import Testing

@testable import Core

@Test func relaunchURLCarriesTheArgumentsInOrder() throws {
    let arguments = ["-UITest", "-FakeCamera", "1", "-FixedDate", "2026-10-12", "-FakeReader"]
    let url = try #require(RelaunchURL.make(arguments: arguments))
    #expect(url.scheme == RelaunchURL.scheme)
    #expect(RelaunchURL.arguments(from: url) == arguments)
}

@Test func relaunchURLKeepsValuesThatNeedEscaping() throws {
    let arguments = ["-UITest", "a b", "c&d=e", "+1", "é"]
    let url = try #require(RelaunchURL.make(arguments: arguments))
    #expect(RelaunchURL.arguments(from: url) == arguments)
}

@Test func relaunchURLWithNoArgumentsIsEmpty() throws {
    let url = try #require(RelaunchURL.make(arguments: []))
    #expect(RelaunchURL.arguments(from: url) == [])
}

@Test func otherURLsAreNotRelaunches() throws {
    for text in [
        "https://relaunch?arg=-UITest", "filingcabinet-uitest://other?arg=-UITest", "filingcabinet://relaunch",
    ] {
        let url = try #require(URL(string: text))
        #expect(RelaunchURL.arguments(from: url) == nil, "\(text)")
    }
}
