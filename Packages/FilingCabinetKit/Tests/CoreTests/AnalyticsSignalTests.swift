import Testing

@testable import Core

@Test func scanSavedBecomesStrings() {
    let event = AnalyticsEvent.scanSaved(pageCount: 3, collection: .receipts)
    #expect(event.signalParameters == ["pageCount": "3", "collection": "receipts"])
}

@Test func boolsAreTrueOrFalse() {
    let event = AnalyticsEvent.suggestionChanged(title: true, collection: false)
    #expect(event.signalParameters == ["titleChanged": "true", "collectionChanged": "false"])
}

@Test func appOpenedHasNoParameters() {
    #expect(AnalyticsEvent.appOpened.signalParameters.isEmpty)
}

@Test func everyEventsParametersMatchItsPayloadKeys() {
    let events: [AnalyticsEvent] = [
        .appOpened, .scanStarted(source: .home), .cameraDenied, .cameraFailed,
        .scanCancelled(stage: .camera), .scanSaved(pageCount: 1, collection: .receipts),
        .saveFailed(reason: .diskFull), .textReadingFailed(failedPages: 2), .scanEdited(field: .title),
        .scanMovedToTrash(collection: .receipts), .scansRestored(count: 1), .scansDeleted(count: 1),
        .trashEmptied(count: 1), .cleanupRan(deleted: 1),
        .lifespanChanged(collection: .receipts, lifespan: Lifespan.allCases[0]),
        .favoritesChanged(isFavorite: true, count: 1), .scansExported(kind: .share, count: 1),
        .searchSaved(resultCount: 1), .suggestionOutcome(.arrived),
        .suggestionChanged(title: false, collection: true), .feedbackOpened(kind: .feedback),
        .libraryOpenFailed, .welcomeFinished(notifications: true), .ratingRequested,
    ]
    for event in events {
        #expect(Set(event.signalParameters.keys) == Set(event.payload.keys.map(\.rawValue)), "\(event.name)")
    }
}
