import Core
import Foundation
import Library
import Observation
import ScreenModels
import Screens
import UIKit
import Understanding
import os

#if DEBUG
    import TestSupport
#endif

/// The app's collaborators, built once at launch from the launch options.
@MainActor
@Observable
final class AppEnvironment {
    private static let logger = Logger(subsystem: "com.cadre.filingcabinet", category: "App")

    #if DEBUG
        private static let isDebugBuild = true
    #else
        private static let isDebugBuild = false
    #endif

    /// Held for the screens that log events; only the lifecycle model uses it so far.
    @ObservationIgnored let analytics: any Analytics
    @ObservationIgnored let clock: AppClock
    @ObservationIgnored let today: Today
    @ObservationIgnored let store: ScanStore
    /// Read by the review (Task 14); built here so the reader flags apply from launch.
    @ObservationIgnored let scanReader: ScanReader
    @ObservationIgnored let lifecycle: AppLifecycleModel
    @ObservationIgnored let root: RootDependencies
    @ObservationIgnored private let options: LaunchOptions

    /// False until launch cleanup (and any seeding) has finished; Scan stays disabled until then.
    private(set) var isReady = false

    private init(options: LaunchOptions) {
        self.options = options
        let analytics = LogAnalytics()
        let clock = options.fixedDate.map { AppClock.fixed($0, calendar: AppClock.system.calendar) } ?? .system
        let location = Self.libraryLocation(isUITest: options.isUITest)
        let fileSystem = LocalFileSystem()
        let store = Self.makeStore(
            location: location,
            inMemory: options.isUITest,
            pageFileSystem: Self.pageFileSystem(fileSystem, options: options)
        )
        self.analytics = analytics
        self.clock = clock
        let today = Today(clock: clock)
        self.today = today
        self.store = store
        scanReader = Self.makeScanReader(options: options)
        lifecycle = AppLifecycleModel(analytics: analytics)
        root = RootDependencies(
            home: HomeModel(library: store, today: today, calendar: clock.calendar),
            thumbnails: ThumbnailLoader(location: location, fileSystem: fileSystem),
            pages: PageImageLoader(location: location, fileSystem: fileSystem),
            cameraMode: Self.cameraMode(options: options)
        )
    }

    /// Unknown flags are ignored, and a Release build ignores every flag (M9).
    static func make(arguments: [String]) -> AppEnvironment {
        let options = LaunchOptions(arguments: arguments, isDebugBuild: isDebugBuild)
        if options.isUITest {
            UIView.setAnimationsEnabled(false)
        }
        return AppEnvironment(options: options)
    }

    /// Clears what an interrupted save left behind, and only then seeds (`-SeedScans`) and enables Scan.
    func launch() async {
        await store.removeOrphanedFiles()
        #if DEBUG
            if let count = options.seedScans {
                do {
                    try await LibrarySeed.seed(store, count: count, clock: clock)
                } catch {
                    Self.logger.error(
                        "Seeding \(count, privacy: .public) scans failed: \(error.localizedDescription, privacy: .private)"
                    )
                }
            }
        #endif
        isReady = true
    }

    /// The real library, or a fresh temporary one for UI tests so runs never see each other's files.
    private static func libraryLocation(isUITest: Bool) -> LibraryLocation {
        if isUITest {
            let base = FileManager.default.temporaryDirectory.appending(path: "UITest-\(UUID().uuidString)")
            return LibraryLocation(root: base.appending(path: "Root"), caches: base.appending(path: "Caches"))
        }
        do {
            return try LibraryLocation.standard()
        } catch {
            logger.fault("No Application Support folder: \(error.localizedDescription, privacy: .private)")
            fatalError("Filing Cabinet cannot find its library folder")
        }
    }

    /// On disk, or in memory for UI tests.
    private static func makeStore(location: LibraryLocation, inMemory: Bool, pageFileSystem: any FileSystem)
        -> ScanStore
    {
        do {
            let container = try ScanStore.makeContainer(storeURL: inMemory ? nil : location.storeURL)
            return ScanStore(container: container, files: PageFileStore(location: location, fileSystem: pageFileSystem))
        } catch {
            // Running on without the store would lose every scan saved this session.
            logger.fault("The library store could not be opened: \(error.localizedDescription, privacy: .private)")
            fatalError("Filing Cabinet cannot open its library")
        }
    }

    private static func pageFileSystem(_ base: any FileSystem, options: LaunchOptions) -> any FileSystem {
        #if DEBUG
            if options.failNextSave { return FailOnceFileSystem(base) }
        #endif
        return base
    }

    private static func makeScanReader(options: LaunchOptions) -> ScanReader {
        #if DEBUG
            if options.fakeReader { return ScanReader(reader: FakeTextReader.readsCityPharmacy()) }
        #endif
        return ScanReader(reader: options.reader.makeReader())
    }

    private static func cameraMode(options: LaunchOptions) -> CameraMode {
        #if DEBUG
            if let count = options.fakeCameraPages {
                return .fake(pages: { (0..<count).map { _ in SyntheticPages.receipt() } })
            }
        #endif
        return .vision
    }
}
