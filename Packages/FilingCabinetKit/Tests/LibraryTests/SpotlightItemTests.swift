import Core
import Foundation
import Library
import Testing

@Test func identifierRoundTrips() {
    let id = ScanID()
    #expect(ScanID(spotlightIdentifier: id.spotlightIdentifier) == id)
    #expect(ScanID(spotlightIdentifier: "com.apple.something-else") == nil)
}
