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

@Test func scanSavedCarriesPageCountAndCollection() {
    let event = AnalyticsEvent.scanSaved(pageCount: 3, collection: .receipts)
    #expect(event.payload == [.pageCount: .int(3), .collection: .token(.init(BuiltInCollection.receipts))])
}

private struct Expected {
    let event: AnalyticsEvent
    let name: String
    let payload: [AnalyticsKey: AnalyticsValue]
}

@Test func scanEventsAreNamedAfterTheirCasesAndCarryTypedValues() {
    let expected = [
        Expected(
            event: .scanStarted(source: .grid), name: "scanStarted", payload: [.source: .token(.init(ScanSource.grid))]),
        Expected(event: .cameraDenied, name: "cameraDenied", payload: [:]),
        Expected(event: .cameraFailed, name: "cameraFailed", payload: [:]),
        Expected(
            event: .scanCancelled(stage: .review),
            name: "scanCancelled",
            payload: [.stage: .token(.init(CancelStage.review))]),
        Expected(
            event: .scanSaved(pageCount: 1, collection: .wallet),
            name: "scanSaved",
            payload: [.pageCount: .int(1), .collection: .token(.init(BuiltInCollection.wallet))]),
        Expected(
            event: .saveFailed(reason: .diskFull),
            name: "saveFailed",
            payload: [.reason: .token(.init(FailureReason.diskFull))]),
        Expected(
            event: .textReadingFailed(failedPages: 2), name: "textReadingFailed", payload: [.failedPages: .int(2)]),
        Expected(
            event: .scanEdited(field: .collection),
            name: "scanEdited",
            payload: [.field: .token(.init(EditedField.collection))]),
        Expected(
            event: .scanMovedToTrash(collection: .receipts),
            name: "scanMovedToTrash",
            payload: [.collection: .token(.init(BuiltInCollection.receipts))]),
        Expected(event: .scansRestored(count: 2), name: "scansRestored", payload: [.count: .int(2)]),
        Expected(event: .scansDeleted(count: 3), name: "scansDeleted", payload: [.count: .int(3)]),
        Expected(event: .trashEmptied(count: 7), name: "trashEmptied", payload: [.count: .int(7)]),
        Expected(event: .cleanupRan(deleted: 4), name: "cleanupRan", payload: [.count: .int(4)]),
        Expected(
            event: .lifespanChanged(collection: .receipts, lifespan: .month),
            name: "lifespanChanged",
            payload: [
                .collection: .token(.init(BuiltInCollection.receipts)), .lifespan: .token(.init(Lifespan.month)),
            ]),
    ]
    for item in expected {
        #expect(item.event.name == item.name)
        #expect(item.event.payload == item.payload, "\(item.name)")
    }
}

@Test func tokensKeepTheirRawValues() {
    #expect(ScanSource.allCases.map(\.rawValue) == ["home", "grid"])
    #expect(CancelStage.allCases.map(\.rawValue) == ["camera", "review"])
    #expect(FailureReason.allCases.map(\.rawValue) == ["diskFull", "writeFailed"])
    #expect(EditedField.allCases.map(\.rawValue) == ["title", "collection", "expiry"])
}
