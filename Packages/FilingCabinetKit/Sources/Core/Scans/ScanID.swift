import Foundation

/// A scan's identity: the one thing that crosses isolation in place of a SwiftData object.
public struct ScanID: Sendable, Hashable, Codable {
    package let uuid: UUID

    package init() {
        self.init(uuid: UUID())
    }

    package init(uuid: UUID) {
        self.uuid = uuid
    }
}
