import Foundation

/// `SNAPSHOT_VARIANTS` named a variant `SnapshotConfig` doesn't have: the run fails rather than draw nothing.
struct UnknownSnapshotVariant: LocalizedError, Equatable {
    let name: String

    var errorDescription: String? {
        let known = SnapshotConfig.variants.map(\.name).joined(separator: ", ")
        return "SNAPSHOT_VARIANTS names \"\(name)\", which isn't a snapshot variant (\(known))"
    }
}
