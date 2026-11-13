import Core
import Foundation
import Library
import Observation
import ScreenModels
import Screens
import UIKit
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
        static let isDebugBuild = true
    #else
        static let isDebugBuild = false
    #endif

    /// Held for the screens that log events.
    @ObservationIgnored let analytics: any Analytics
    @ObservationIgnored let clock: AppClock
    @ObservationIgnored let today: Today
    @ObservationIgnored let store: ScanStore
    /// Shared PDFs, in the temporary folder (M20).
    @ObservationIgnored private let export: ScanExport
    @ObservationIgnored let lifecycle: AppLifecycleModel
    @ObservationIgnored let banner: CleanupBanner
    @ObservationIgnored let notifier: CleanupNotifier
    @ObservationIgnored let root: RootDependencies
    @ObservationIgnored private let options: LaunchOptions
    @ObservationIgnored private let preferences: AppPreferences
    /// Gives older scans their search words while the app is in the foreground (M9).
    @ObservationIgnored private let wordsPass: SearchWordsPass

    /// False until launch cleanup (and any seeding) has finished; Scan stays disabled until then.
    private(set) var isReady = false
    /// Set by the first `launch()`, so a rebuilt scene doesn't clean up or seed again.
    @ObservationIgnored private var hasLaunched = false

    #if DEBUG
        /// Under `-UITest`, `-SeedScans` makes Home's banner count what expired in this many days before today.
        private static let uiTestDaysSinceSeen = 14
    #endif

    private init(options: LaunchOptions, isRetry: Bool) throws(LibraryOpenFailure) {
        self.options = options
        let analytics = LogAnalytics()
        let clock = options.fixedDate.map { AppClock.fixed($0, calendar: AppClock.system.calendar) } ?? .system
        let location = try Self.libraryLocation(isUITest: options.isUITest)
        let fileSystem = LocalFileSystem()
        let files = PageFileStore(location: location, fileSystem: Self.pageFileSystem(fileSystem, options: options))
        let store = try Self.makeStore(
            location: location, options: options, isRetry: isRetry, files: files, clock: clock)
        let export = ScanExport(files: files)
        self.export = export
        self.analytics = analytics
        self.clock = clock
        let today = Today(clock: clock)
        self.today = today
        self.store = store
        lifecycle = AppLifecycleModel(analytics: analytics)
        let (preferences, history) = Self.makeKept(options: options)
        self.preferences = preferences
        let notifications = Self.notificationCenter(options: options)
        let banner = CleanupBanner(
            library: store, today: today, preferences: preferences, notifications: notifications)
        self.banner = banner
        notifier = CleanupNotifier(
            library: store, today: today, preferences: preferences, center: notifications, clock: clock)
        let scanning = Scanning(
            options: options, store: store, today: today, clock: clock, analytics: analytics, preferences: preferences)
        wordsPass = scanning.wordsPass
        let viewerShared = ViewerShared(history: history, export: export, photos: Self.photoSaving(options: options))
        root = RootDependencies(
            home: HomeModel(library: store, today: today, calendar: clock.calendar, banner: banner),
            flow: scanning.flow,
            makeGrid: Self.gridMaker(store: store, today: today, clock: clock, analytics: analytics, export: export),
            makeTrash: { TrashModel(library: store, today: today, calendar: clock.calendar, analytics: analytics) },
            makeViewer: Self.viewerMaker(
                store: store, today: today, clock: clock, analytics: analytics, with: viewerShared),
            makeDetails: { DetailsModel(id: $0, library: store, today: today, clock: clock, analytics: analytics) },
            makeSettings: { scanning.settings(preferences: preferences, notifications: notifications) },
            makeCollections: { CollectionsModel(library: store, today: today, calendar: clock.calendar) },
            makeCollectionSettings: Self.collectionSettingsMaker(
                store: store, today: today, clock: clock, analytics: analytics),
            makeSearch: Self.searchMaker(
                store: store, today: today, clock: clock, analytics: analytics, history: history),
            thumbnails: ThumbnailLoader(location: location, fileSystem: fileSystem),
            pages: PageImageLoader(location: location, fileSystem: fileSystem),
            cameraMode: Self.cameraMode(options: options),
            forcesReduceMotion: options.reduceMotion,
            preferences: preferences,
            welcome: WelcomeModel(preferences: preferences, notifications: notifications, analytics: analytics)
        )
    }

    /// Makes a collection's Settings screen model (10-03).
    private static func collectionSettingsMaker(
        store: ScanStore, today: Today, clock: AppClock, analytics: any Analytics
    ) -> (BuiltInCollection) -> CollectionSettingsModel {
        { collection in
            CollectionSettingsModel(
                collection: collection, library: store, today: today, calendar: clock.calendar, analytics: analytics)
        }
    }

    /// Makes a grid's model; `export` makes the PDFs its selection shares.
    private static func gridMaker(
        store: ScanStore, today: Today, clock: AppClock, analytics: any Analytics, export: ScanExport
    ) -> (GridKind) -> CollectionGridModel {
        { kind in
            CollectionGridModel(
                kind: kind, library: store, today: today, calendar: clock.calendar, analytics: analytics, export: export
            )
        }
    }

    /// Makes Search's model, keeping what it saves in the app-wide history the viewer records into.
    private static func searchMaker(
        store: ScanStore, today: Today, clock: AppClock, analytics: any Analytics, history: SearchHistory
    ) -> () -> SearchModel {
        { SearchModel(library: store, today: today, clock: clock, history: history, analytics: analytics) }
    }

    /// Unknown flags are ignored, and a Release build ignores every flag (M9). Throws when the library can't open;
    /// `isRetry` is the failure screen's Try again, which `-FailLibraryOpen once` lets through.
    static func make(arguments: [String], isRetry: Bool = false) throws(LibraryOpenFailure) -> AppEnvironment {
        let options = LaunchOptions(arguments: arguments, isDebugBuild: isDebugBuild)
        if options.isUITest {
            UIView.setAnimationsEnabled(false)
        }
        return try AppEnvironment(options: options, isRetry: isRetry)
    }

    /// Clears what an interrupted save left behind and any exported PDF a share left (M20), deletes what has had its 30
    /// days in Trash, and only then seeds
    /// (`-SeedScans` with `-SeedFavorites`, `-SeedTrash`) and enables Scan. Then reads what iOS allows for Home's banner.
    func launch() async {
        guard !hasLaunched else { return }
        hasLaunched = true
        await LaunchCleanup(store: store, export: export).run()
        await purgeTrash()
        #if DEBUG
            if let count = options.seedScans {
                do {
                    try await LibrarySeed.seed(
                        store, count: count, favorites: options.seedFavorites ?? 0, clock: clock)
                } catch {
                    Self.logger.error(
                        "Seeding \(count, privacy: .public) scans failed: \(error.localizedDescription, privacy: .private)"
                    )
                }
                if options.isUITest {
                    // As if Home was last seen two weeks ago, so seeded scans that expired since then make a banner.
                    preferences.cleanupSeenThrough = clock.today.adding(
                        days: -Self.uiTestDaysSinceSeen, in: clock.calendar)
                }
            }
            if let count = options.seedTrash {
                do {
                    try await LibrarySeed.seedTrash(store, count: count, clock: clock)
                } catch {
                    Self.logger.error(
                        "Seeding \(count, privacy: .public) scans in Trash failed: \(error.localizedDescription, privacy: .private)"
                    )
                }
            }
        #endif
        // Before asking iOS about notifications: Scan doesn't need the answer, and iOS can be slow to give it.
        isReady = true
        wordsPass.resume()
        await banner.refreshAuthorization()
    }

    /// Back in the app (the app has already refreshed today): a new time zone or a new answer in iPhone Settings may
    /// have come meanwhile. Once launch has finished, Trash is purged again.
    func becameActive() async {
        notifier.reschedule()
        await banner.refreshAuthorization()
        guard isReady else { return }
        await purgeTrash()
        wordsPass.resume()
    }

    /// Leaving the foreground, or replaced by a UI test's relaunch: older scans' reading stops, and a `resume()` still
    /// to come from launch or `becameActive` does nothing until `enteredForeground`.
    func leftForeground() {
        wordsPass.leftForeground()
    }

    /// Back in the foreground: called at once on `.active`, before `becameActive`'s awaits, so they can't race it.
    func enteredForeground() {
        wordsPass.enteredForeground()
    }

    /// Deletes every scan past its 30 days in Trash, and reports a pass that deleted any.
    private func purgeTrash() async {
        let deleted = await store.purgeTrash()
        if deleted > 0 { analytics.send(.cleanupRan(deleted: deleted)) }
    }

    /// The real library, or a fresh temporary one for UI tests so runs never see each other's files.
    private static func libraryLocation(isUITest: Bool) throws(LibraryOpenFailure) -> LibraryLocation {
        if isUITest {
            let base = FileManager.default.temporaryDirectory.appending(path: "UITest-\(UUID().uuidString)")
            return LibraryLocation(root: base.appending(path: "Root"), caches: base.appending(path: "Caches"))
        }
        do {
            return try LibraryLocation.standard()
        } catch {
            logger.fault("No Application Support folder: \(error.localizedDescription, privacy: .private)")
            throw LibraryOpenFailure(underlying: error)
        }
    }

    /// The phone's preferences, or for UI tests a suite emptied at each launch, so no run reads or leaves real ones.
    private static func preferencesDefaults(isUITest: Bool) -> UserDefaults {
        guard isUITest else { return .standard }
        let suite = "com.cadre.filingcabinet.UITest"
        guard let defaults = UserDefaults(suiteName: suite) else {
            logger.fault("The UI-test preferences suite could not be made")
            fatalError("Filing Cabinet cannot keep UI-test preferences apart")
        }
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    /// What is kept in the phone's defaults: the settings and Search's history. UI tests start past the welcome unless
    /// `-ShowWelcome` asks to see it (M1).
    private static func makeKept(options: LaunchOptions) -> (AppPreferences, SearchHistory) {
        let defaults = preferencesDefaults(isUITest: options.isUITest)
        let preferences = AppPreferences(defaults: defaults)
        if options.isUITest {
            preferences.welcomeDone = !options.showWelcome
        }
        return (preferences, SearchHistory(defaults: defaults))
    }

    /// The system's notifications, or a scripted answer for `-Notifications` (none for `-NotificationsUnanswered`).
    private static func notificationCenter(options: LaunchOptions) -> any CleanupNotifying {
        #if DEBUG
            if options.notificationsUnanswered {
                return FakeNotificationCenter(authorization: options.notifications ?? .notDetermined, answers: false)
            }
            if let authorization = options.notifications {
                return FakeNotificationCenter(authorization: authorization)
            }
        #endif
        return SystemNotificationCenter()
    }

    /// On disk, or in memory for UI tests.
    private static func makeStore(
        location: LibraryLocation, options: LaunchOptions, isRetry: Bool, files: PageFileStore, clock: AppClock
    ) throws(LibraryOpenFailure) -> ScanStore {
        do {
            try failIfAsked(options.failLibraryOpen, isRetry: isRetry)
            let container = try ScanStore.makeContainer(storeURL: options.isUITest ? nil : location.storeURL)
            return ScanStore(container: container, files: files, clock: clock)
        } catch {
            // Running on without the store would lose every scan saved this session, so the failure screen shows.
            logger.fault("The library store could not be opened: \(error.localizedDescription, privacy: .private)")
            throw LibraryOpenFailure(underlying: error)
        }
    }

    /// `-FailLibraryOpen`: opening fails as a damaged store would, on every attempt or (`once`) only the first.
    /// Always nil in Release, where `LaunchOptions` ignores every flag.
    private static func failIfAsked(_ failure: FailLibraryOpen?, isRetry: Bool) throws {
        switch failure {
        case .always: throw CocoaError(.fileReadCorruptFile)
        case .once where !isRetry: throw CocoaError(.fileReadCorruptFile)
        case .once, nil: return
        }
    }

    private static func pageFileSystem(_ base: any FileSystem, options: LaunchOptions) -> any FileSystem {
        #if DEBUG
            if options.failNextSave { return FailOnceFileSystem(base) }
        #endif
        return base
    }

    /// The system's answer, or a scripted one for `-CameraDenied` and the fake camera (which needs no permission).
    static func cameraAccess(options: LaunchOptions) -> any CameraAccess {
        #if DEBUG
            if options.cameraDenied { return FakeCameraAccess(status: .denied, grantsOnRequest: false) }
            if options.fakeCameraPages != nil { return FakeCameraAccess(status: .authorized, grantsOnRequest: true) }
        #endif
        return SystemCameraAccess()
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

/// The viewer, and what it sends out of the app.
extension AppEnvironment {
    /// What every viewer shares with the app: Search's history, and what Share and More send scans out with.
    private struct ViewerShared {
        let history: SearchHistory
        let export: ScanExport
        let photos: any PhotoSaving
    }

    /// Makes the viewer for a scan, opened from the library (which records it in Search's history) or from Trash.
    private static func viewerMaker(
        store: ScanStore, today: Today, clock: AppClock, analytics: any Analytics, with shared: ViewerShared
    ) -> (ScanID, ViewerModel.Mode) -> ViewerModel {
        { id, mode in
            ViewerModel(
                id: id,
                library: store,
                today: today,
                calendar: clock.calendar,
                analytics: analytics,
                history: shared.history,
                export: shared.export,
                photos: shared.photos,
                mode: mode)
        }
    }

    /// The system's Photos, or a scripted answer for `-Photos`, so a UI test never sees the system prompt.
    private static func photoSaving(options: LaunchOptions) -> any PhotoSaving {
        #if DEBUG
            if let authorization = options.photos { return FakePhotoSaving(authorization) }
        #endif
        return SystemPhotoSaving()
    }
}
