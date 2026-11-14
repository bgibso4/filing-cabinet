import Foundation
import Testing

@testable import ScreenModels

private let details = DeviceDetails(version: "1.0", build: "14", system: "iOS 27.2", model: "iPhone17,3")
private let line = "Filing Cabinet 1.0 (14) · iOS 27.2 · iPhone17,3"

private struct LibraryError: LocalizedError {
    var errorDescription: String? { "Couldn't open & read the store" }
}

private func fields(_ url: URL) throws -> [String: String] {
    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    let items = components.queryItems ?? []
    return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
}

@Test func feedbackHasSubjectAndDetails() throws {
    let url = FeedbackMail.feedback(details)
    let parts = try fields(url)
    #expect(url.scheme == "mailto")
    #expect(URLComponents(url: url, resolvingAgainstBaseURL: false)?.path == FeedbackAddress.value)
    #expect(parts["subject"] == "Filing Cabinet feedback")
    #expect(parts["body"]?.hasSuffix(line) == true)
    #expect(parts["body"]?.contains("Error:") == false)
}

@Test func reportAddsTheErrorLine() throws {
    let error = NSError(domain: "NSCocoaErrorDomain", code: 4, userInfo: [NSLocalizedDescriptionKey: "No such file"])
    let parts = try fields(FeedbackMail.report(details, error: error))
    #expect(parts["subject"] == "Filing Cabinet · library couldn't open")
    #expect(parts["body"] == "\n\n · · · \n" + line + "\nError: NSCocoaErrorDomain 4 · No such file")
}

@Test func bodyLeavesRoomAtTheTop() throws {
    let body = try #require(fields(FeedbackMail.feedback(details))["body"])
    #expect(body.hasPrefix("\n\n"))
}

@Test func encodesSpacesAndMiddots() {
    let text = FeedbackMail.feedback(details).absoluteString
    #expect(!text.contains(" "))
    #expect(!text.contains("·"))
    #expect(text.contains("%C2%B7"))
}

@Test func errorTextWithReservedCharactersSurvives() throws {
    let parts = try fields(FeedbackMail.report(details, error: LibraryError()))
    #expect(parts["body"]?.hasSuffix("· Couldn't open & read the store") == true)
}

@Test func noScanContentEver() throws {
    // Built from a DeviceDetails and an error only, so the URL holds nothing else.
    let parts = try fields(FeedbackMail.report(details, error: LibraryError()))
    #expect(Set(parts.keys) == ["subject", "body"])
    let body = try #require(parts["body"])
    #expect(body.split(separator: "\n").count == 3)
}

@Test func noMailAppShowsTheAddress() {
    let message = FeedbackMail.noMailMessage(address: FeedbackAddress.value)
    #expect(message == "Send your note to \(FeedbackAddress.value)")
}

@Test func feedbackGoesToARealAddress() {
    #expect(FeedbackAddress.value != FeedbackAddress.placeholder)
    #expect(FeedbackMail.feedback(details).absoluteString.hasPrefix("mailto:\(FeedbackAddress.value)?"))
}

@Test func privacyPolicyIsAnHTTPSPage() {
    #expect(PrivacyPolicy.url.scheme == "https")
}

@Test func detailsLineUsesMiddots() {
    #expect(details.detailsLine == line)
}

@Test func currentDetailsReadTheBundleAndSystem() {
    let current = DeviceDetails.current()
    #expect(current.system.hasPrefix("iOS "))
    #expect(!current.model.isEmpty)
}
