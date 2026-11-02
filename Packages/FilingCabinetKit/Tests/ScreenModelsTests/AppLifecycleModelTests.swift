import TestSupport
import Testing

@testable import ScreenModels

@Test func becomingActiveSendsAppOpened() {
    let fake = RecordingAnalytics()
    let model = AppLifecycleModel(analytics: fake)
    model.sceneBecameActive()
    model.sceneBecameActive()
    #expect(fake.events == [.appOpened, .appOpened])
}
