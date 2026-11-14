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
    "-SeedTrash", "5",
    "-FailSave",
    "-FakeReader",
    "-ReduceMotion",
    "-TextReader", "documents",
    "-Notifications", "denied",
    "-NotificationsUnanswered",
    "-Photos", "denied",
    "-Suggestions", "slow",
    "-FailLibraryOpen",
    "-ShowWelcome",
    "-Request", "scan",
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
    #expect(options.seedTrash == 5)
    #expect(options.failNextSave)
    #expect(options.fakeReader)
    #expect(options.reduceMotion)
    #expect(options.reader == .documents)
    #expect(options.notifications == .denied)
    #expect(options.notificationsUnanswered)
    #expect(options.photos == .denied)
    #expect(options.suggestions == .slow)
    #expect(options.failLibraryOpen == .always)
    #expect(options.showWelcome)
    #expect(options.request == .scan)
}

@Test func parsesSeedFavorites() {
    #expect(LaunchOptions(arguments: ["-SeedFavorites", "3"], isDebugBuild: true).seedFavorites == 3)
    #expect(LaunchOptions(arguments: ["-SeedFavorites", "-1"], isDebugBuild: true).seedFavorites == nil)
    #expect(LaunchOptions(arguments: ["-SeedFavorites", "3"], isDebugBuild: false).seedFavorites == nil)
}

@Test func releaseIgnoresEveryFlag() {
    let options = LaunchOptions(arguments: everyFlag, isDebugBuild: false)
    #expect(options == LaunchOptions(arguments: [], isDebugBuild: true))
    #expect(!options.isUITest)
    #expect(options.fakeCameraPages == nil)
    #expect(!options.cameraDenied)
    #expect(options.fixedDate == nil)
    #expect(options.seedScans == nil)
    #expect(options.seedTrash == nil)
    #expect(!options.failNextSave)
    #expect(!options.fakeReader)
    #expect(!options.reduceMotion)
    #expect(options.reader == .text)
    #expect(options.notifications == nil)
    #expect(!options.notificationsUnanswered)
    #expect(options.photos == nil)
    #expect(options.suggestions == nil)
    #expect(options.failLibraryOpen == nil)
    #expect(options.request == nil)
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

@Test(arguments: [
    ("authorized", NotificationAuthorization.authorized), ("denied", .denied), ("notDetermined", .notDetermined),
])
func notificationsFlagScriptsAuthorization(_ value: String, _ expected: NotificationAuthorization) {
    #expect(LaunchOptions(arguments: ["-Notifications", value], isDebugBuild: true).notifications == expected)
}

@Test func unknownNotificationsValueIsIgnored() {
    #expect(LaunchOptions(arguments: ["-Notifications", "maybe"], isDebugBuild: true).notifications == nil)
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

@Test func parsesSeedTrash() {
    #expect(LaunchOptions(arguments: ["-SeedTrash", "7"], isDebugBuild: true).seedTrash == 7)
    #expect(LaunchOptions(arguments: ["-SeedTrash", "0"], isDebugBuild: true).seedTrash == 0)
    #expect(LaunchOptions(arguments: ["-SeedTrash", "-2"], isDebugBuild: true).seedTrash == nil)
    #expect(LaunchOptions(arguments: ["-SeedTrash", "some"], isDebugBuild: true).seedTrash == nil)
    #expect(LaunchOptions(arguments: ["-SeedTrash", "3"], isDebugBuild: false).seedTrash == nil)
}

@Test(arguments: [("authorized", PhotosAuthorization.authorized), ("denied", .denied)])
func photosFlagScriptsAuthorization(_ value: String, _ expected: PhotosAuthorization) {
    #expect(LaunchOptions(arguments: ["-Photos", value], isDebugBuild: true).photos == expected)
}

@Test func unknownPhotosValueIsIgnored() {
    #expect(LaunchOptions(arguments: ["-Photos", "limited"], isDebugBuild: true).photos == nil)
}

@Test(arguments: [("arrives", SuggestionsFlag.arrives), ("slow", .slow), ("unavailable", .unavailable)])
func parsesSuggestions(_ value: String, _ expected: SuggestionsFlag) {
    #expect(LaunchOptions(arguments: ["-Suggestions", value], isDebugBuild: true).suggestions == expected)
}

@Test func unknownSuggestionsValueIsIgnored() {
    #expect(LaunchOptions(arguments: ["-Suggestions", "sometimes"], isDebugBuild: true).suggestions == nil)
}

@Test func parsesFailLibraryOpen() {
    #expect(LaunchOptions(arguments: ["-FailLibraryOpen"], isDebugBuild: true).failLibraryOpen == .always)
    #expect(LaunchOptions(arguments: ["-FailLibraryOpen", "-UITest"], isDebugBuild: true).failLibraryOpen == .always)
    #expect(LaunchOptions(arguments: ["-FailLibraryOpen", "once"], isDebugBuild: true).failLibraryOpen == .once)
    #expect(LaunchOptions(arguments: ["-FailLibraryOpen", "once"], isDebugBuild: false).failLibraryOpen == nil)
    #expect(LaunchOptions(arguments: ["-UITest"], isDebugBuild: true).failLibraryOpen == nil)
}

@Test func parsesShowWelcome() {
    #expect(LaunchOptions(arguments: ["-ShowWelcome"], isDebugBuild: true).showWelcome)
    #expect(!LaunchOptions(arguments: ["-UITest"], isDebugBuild: true).showWelcome)
    #expect(!LaunchOptions(arguments: ["-ShowWelcome"], isDebugBuild: false).showWelcome)
}

@Test func parsesHoldScan() {
    #expect(LaunchOptions(arguments: ["-HoldScan"], isDebugBuild: true).holdScan)
    #expect(!LaunchOptions(arguments: ["-UITest"], isDebugBuild: true).holdScan)
    #expect(!LaunchOptions(arguments: ["-HoldScan"], isDebugBuild: false).holdScan)
}

@Test func parsesRequest() {
    func request(_ value: String) -> RequestFlag? {
        LaunchOptions(arguments: ["-Request", value], isDebugBuild: true).request
    }
    #expect(request("scan") == .scan)
    #expect(request("search:city pharmacy") == .search("city pharmacy"))
    #expect(request("open:2") == .open(seeded: 2))
    #expect(request("open:0") == nil)
    #expect(request("open:x") == nil)
    #expect(request("search:") == nil)
    #expect(request("print") == nil)
    #expect(LaunchOptions(arguments: ["-Request", "scan"], isDebugBuild: false).request == nil)
}
