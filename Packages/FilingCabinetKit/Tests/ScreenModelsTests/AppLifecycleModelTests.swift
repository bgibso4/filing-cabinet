import TestSupport
import Testing

@testable import ScreenModels

@Test func becomingActiveSendsAppOpened() {
    let fake = RecordingAnalytics()
    let model = AppLifecycleModel(analytics: fake)
    model.sceneBecameActive()
    model.sceneLeftForeground()
    model.sceneBecameActive()
    #expect(fake.events == [.appOpened, .appOpened])
}

@Test func launchThenActiveCountsOnce() {
    let fake = RecordingAnalytics()
    let model = AppLifecycleModel(analytics: fake)
    model.launched()
    model.sceneBecameActive()
    #expect(fake.events == [.appOpened])
}

@Test func activeThenLaunchCountsOnce() {
    let fake = RecordingAnalytics()
    let model = AppLifecycleModel(analytics: fake)
    model.sceneBecameActive()
    model.launched()
    #expect(fake.events == [.appOpened])
}

@Test func leavingAndComingBackCountsAgain() {
    let fake = RecordingAnalytics()
    let model = AppLifecycleModel(analytics: fake)
    model.launched()
    model.sceneLeftForeground()
    model.sceneBecameActive()
    #expect(fake.events == [.appOpened, .appOpened])
}

@Test func becomingActiveAgainWithoutLeavingCountsOnce() {
    let fake = RecordingAnalytics()
    let model = AppLifecycleModel(analytics: fake)
    model.sceneBecameActive()
    model.sceneBecameActive()
    #expect(fake.events == [.appOpened])
}
