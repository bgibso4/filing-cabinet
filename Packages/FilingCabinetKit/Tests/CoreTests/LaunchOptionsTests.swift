import Foundation
import Testing

@testable import Core

private let everyFlag = [
    "/path/to/FilingCabinet",
    "-UITest",
    "-FakeCamera", "2",
    "-CameraDenied",
    "-FixedDate", "2026-10-12",
    "-SeedScans", "12",
    "-FailSave",
    "-FakeReader",
    "-TextReader", "documents",
]

/// 2026-10-12 at 12:00 UTC.
private let octoberTwelfthNoonUTC = Date(timeIntervalSince1970: 1_791_806_400)

@Test func parsesEveryFlagInDebug() {
    let options = LaunchOptions(arguments: everyFlag, isDebugBuild: true)
    #expect(options.isUITest)
    #expect(options.fakeCameraPages == 2)
    #expect(options.cameraDenied)
    #expect(options.fixedDate == octoberTwelfthNoonUTC)
    #expect(options.seedScans == 12)
    #expect(options.failNextSave)
    #expect(options.fakeReader)
    #expect(options.reader == .documents)
}

@Test func releaseIgnoresEveryFlag() {
    let options = LaunchOptions(arguments: everyFlag, isDebugBuild: false)
    #expect(options == LaunchOptions(arguments: [], isDebugBuild: true))
    #expect(!options.isUITest)
    #expect(options.fakeCameraPages == nil)
    #expect(!options.cameraDenied)
    #expect(options.fixedDate == nil)
    #expect(options.seedScans == nil)
    #expect(!options.failNextSave)
    #expect(!options.fakeReader)
    #expect(options.reader == .text)
}

@Test func unknownFlagsAreIgnored() {
    let options = LaunchOptions(
        arguments: ["-Bogus", "3", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL", "-UITest"],
        isDebugBuild: true)
    #expect(options == LaunchOptions(arguments: ["-UITest"], isDebugBuild: true))
}

@Test func fixedDateIsNoonUTC() {
    let options = LaunchOptions(arguments: ["-FixedDate", "2026-10-12"], isDebugBuild: true)
    #expect(options.fixedDate == octoberTwelfthNoonUTC)
}

@Test(arguments: ["2026-13-01", "2026-02-30", "12/10/2026", "tomorrow"])
func invalidFixedDateIsIgnored(_ value: String) {
    #expect(LaunchOptions(arguments: ["-FixedDate", value], isDebugBuild: true).fixedDate == nil)
}

@Test func readerDefaultsToText() {
    #expect(LaunchOptions(arguments: [], isDebugBuild: true).reader == .text)
    #expect(LaunchOptions(arguments: ["-TextReader", "magic"], isDebugBuild: true).reader == .text)
    #expect(LaunchOptions(arguments: ["-TextReader", "text"], isDebugBuild: true).reader == .text)
}

@Test func missingValueIsIgnored() {
    let trailing = LaunchOptions(arguments: ["-UITest", "-FakeCamera"], isDebugBuild: true)
    #expect(trailing.fakeCameraPages == nil)
    #expect(trailing.isUITest)

    // A flag where the value should be is not consumed: it still counts as a flag.
    let followed = LaunchOptions(arguments: ["-FakeCamera", "-SeedScans", "4"], isDebugBuild: true)
    #expect(followed.fakeCameraPages == nil)
    #expect(followed.seedScans == 4)
}

@Test(arguments: ["0", "4", "-1", "two"])
func fakeCameraOutsideOneToThreeIsIgnored(_ value: String) {
    #expect(LaunchOptions(arguments: ["-FakeCamera", value], isDebugBuild: true).fakeCameraPages == nil)
}

@Test(arguments: ["-3", "many"])
func invalidSeedCountIsIgnored(_ value: String) {
    #expect(LaunchOptions(arguments: ["-SeedScans", value], isDebugBuild: true).seedScans == nil)
}
