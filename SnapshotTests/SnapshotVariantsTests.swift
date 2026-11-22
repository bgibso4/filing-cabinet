import Testing

/// Which variants a run draws: `SNAPSHOT_VARIANTS` (`make affected` and `make retest` set light and largest text;
/// CI and `make full` leave it unset).
struct SnapshotVariantsTests {
    @Test func unsetDrawsEveryVariant() throws {
        #expect(try SnapshotConfig.variants(named: nil).map(\.name) == ["light", "dark", "ax5"])
    }

    @Test func emptyDrawsEveryVariant() throws {
        #expect(try SnapshotConfig.variants(named: "").map(\.name) == ["light", "dark", "ax5"])
    }

    @Test func aListPicksThoseInTheConfigsOrder() throws {
        #expect(try SnapshotConfig.variants(named: "ax5, light").map(\.name) == ["light", "ax5"])
    }

    /// A misspelt name must fail the run, never pass having drawn nothing.
    @Test func anUnknownNameThrows() {
        #expect(throws: UnknownSnapshotVariant(name: "lite")) {
            try SnapshotConfig.variants(named: "light,lite")
        }
    }
}
