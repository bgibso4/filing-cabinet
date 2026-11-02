import TestSupport
import Testing

@testable import Core

@Test func appOpenedHasNameAndNoPayload() {
    #expect(AnalyticsEvent.appOpened.name == "appOpened")
    #expect(AnalyticsEvent.appOpened.payload.isEmpty)
}

@Test func recordingFakeKeepsOrder() {
    let fake = RecordingAnalytics()
    fake.send(.appOpened)
    fake.send(.appOpened)
    #expect(fake.events == [.appOpened, .appOpened])
}
