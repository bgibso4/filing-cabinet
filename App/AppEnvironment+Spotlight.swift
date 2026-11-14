import Core
import Library
import ScreenModels

#if DEBUG
    import TestSupport
#endif

/// iPhone search.
extension AppEnvironment {
    /// The sync for the library at `location`: page 1's cached JPEG as each thumbnail, read off the main actor.
    static func spotlightSync(
        store: ScanStore,
        today: Today,
        preferences: AppPreferences,
        at location: LibraryLocation,
        _ options: LaunchOptions
    ) -> SpotlightSync {
        let thumbnails = ThumbnailLoader(location: location, fileSystem: LocalFileSystem())
        return SpotlightSync(
            library: store,
            today: today,
            index: spotlightIndex(options: options),
            thumbnails: { await thumbnails.firstPageJPEG(for: $0) },
            preferences: preferences)
    }

    /// The phone's Spotlight, or for UI tests one in memory, so no run adds to the phone's search.
    private static func spotlightIndex(options: LaunchOptions) -> any SpotlightIndexing {
        #if DEBUG
            if options.isUITest { return FakeSpotlightIndex() }
        #endif
        return CoreSpotlightIndex()
    }
}
