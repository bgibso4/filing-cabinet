import Core

/// One recorded call on a fake image provider.
package struct FakeImageRequest: Equatable, Sendable {
    /// `.cached` is a synchronous memory lookup; `.loaded` is an async load.
    package enum Kind: Equatable, Sendable {
        case cached
        case loaded
    }

    package let id: ScanID
    package let page: Int
    package let kind: Kind

    package init(id: ScanID, page: Int, kind: Kind) {
        self.id = id
        self.page = page
        self.kind = kind
    }
}
