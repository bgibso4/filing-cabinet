import Core
import Foundation
import Testing

@testable import ScreenModels
@testable import TestSupport

private let details = DeviceDetails(version: "1.0", build: "14", system: "iOS 27.2", model: "iPhone17,3")
private let error = CocoaError(.fileReadCorruptFile)

@Test func retrySucceedsHandsBackTheEnvironment() {
    var calls = 0
    let model = LibraryFailureModel(error: error, details: details, analytics: RecordingAnalytics()) {
        calls += 1
        return true
    }
    model.tryAgain()
    #expect(calls == 1)
    #expect(model.announcement == nil)
}

@Test func retryFailsAnnounces() {
    var calls = 0
    let model = LibraryFailureModel(error: error, details: details, analytics: RecordingAnalytics()) {
        calls += 1
        return false
    }
    model.tryAgain()
    #expect(calls == 1)
    #expect(model.announcement == "Still couldn’t open")
}

@Test func reportEmailCarriesTheError() {
    let model = LibraryFailureModel(error: error, details: details, analytics: RecordingAnalytics()) { false }
    #expect(model.reportURL == FeedbackMail.report(details, error: error))
}

@Test func sendReportReportsItsKind() {
    let analytics = RecordingAnalytics()
    let model = LibraryFailureModel(error: error, details: details, analytics: analytics) { false }
    model.reportOpened()
    #expect(analytics.events == [.feedbackOpened(kind: .report)])
}
