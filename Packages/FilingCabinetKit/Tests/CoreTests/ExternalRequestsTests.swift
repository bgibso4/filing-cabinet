import Testing

@testable import Core

@MainActor
@Test func newerReplacesOlder() {
    let requests = ExternalRequests()
    let scan = ScanID()

    requests.send(.scan)
    requests.send(.search("lease"))
    #expect(requests.pending == .search("lease"))
    requests.send(.open(scan))
    #expect(requests.pending == .open(scan))
}

@MainActor
@Test func takeEmpties() {
    let requests = ExternalRequests()
    requests.send(.search("lease"))

    #expect(requests.take() == .search("lease"))
    #expect(requests.pending == nil)
    #expect(requests.take() == nil)
}

@MainActor
@Test func twoScansMakeOneCamera() {
    let requests = ExternalRequests()

    requests.send(.scan)
    requests.send(.scan)

    #expect(requests.take() == .scan)
    #expect(requests.take() == nil)
}
