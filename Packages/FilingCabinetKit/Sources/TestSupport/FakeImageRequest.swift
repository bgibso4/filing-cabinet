import Core

/// One recorded call on a fake image provider.
public struct FakeImageRequest: Equatable, Sendable {
    /// `.cached` is a synchronous memory lookup; `.loaded` is an async load.
    public enum Kind: Equatable, Sendable {
        case cached
        case loaded
    }

    public let id: ScanID
    public let page: Int
    public let kind: Kind

    package init(id: ScanID, page: Int, kind: Kind) {
        self.id = id
        self.page = page
        self.kind = kind
    }
}
