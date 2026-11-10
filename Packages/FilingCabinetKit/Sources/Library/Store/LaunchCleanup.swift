/// What launch clears before anything else: page files an interrupted save left behind, and every exported PDF, the
/// safety net for a share or file export that never ended (M20).
@MainActor
public struct LaunchCleanup {
    private let store: ScanStore
    private let export: ScanExport

    public init(store: ScanStore, export: ScanExport) {
        self.store = store
        self.export = export
    }

    public func run() async {
        await store.removeOrphanedFiles()
        export.removeAll()
    }
}
