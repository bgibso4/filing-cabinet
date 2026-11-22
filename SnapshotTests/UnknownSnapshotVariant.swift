/// `SNAPSHOT_VARIANTS` named a variant `SnapshotConfig` doesn't have: the run fails rather than draw nothing.
struct UnknownSnapshotVariant: Error, Equatable {
    let name: String
}
