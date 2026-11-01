import Foundation
import Testing

@testable import ScreenModels

// `#bundle` in a test file names the test bundle, so these read ScreenModels' bundle explicitly.
@Test func pluralsResolveFromThisModulesCatalog() {
    #expect(String(localized: "\(1) weeks", bundle: .module) == "1 week")
    #expect(String(localized: "\(2) months", bundle: .module) == "2 months")
}
