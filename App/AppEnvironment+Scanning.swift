import Core
import Library
import ScreenModels
import Understanding

#if DEBUG
    import TestSupport
#endif

/// The scan flow, the model's suggestions, and the reading of older scans' search words (M9).
extension AppEnvironment {
    /// How long Save waits for reading before saving without search text (M2); set from Ben's iPhone numbers (A15).
    private static let readingWaitLimit = Duration.seconds(1)
    /// How long the card waits for the model before growing into the sheet (M6, E1).
    private static let suggestionWaitLimit = Duration.seconds(5)
    /// How long `-Suggestions arrives` takes to answer each call.
    private static let fakeSuggestionDelay = Duration.milliseconds(300)

    /// The model, the scan flow and the background words pass, sharing one model and the Settings switch.
    struct Scanning {
        let flow: ScanFlowModel
        let suggester: any ScanSuggester
        /// Stopped during a scan, and waits behind a words call after Save: review has the model to itself.
        let wordsPass: SearchWordsPass
        private let analytics: any Analytics

        init(
            options: LaunchOptions,
            store: ScanStore,
            today: Today,
            clock: AppClock,
            analytics: any Analytics,
            preferences: AppPreferences
        ) {
            let suggester = AppEnvironment.makeSuggester(options: options)
            let wordsWriter = SearchWordsWriter(
                suggester: suggester, library: store, backgroundTime: SystemBackgroundTime())
            let scanReader = AppEnvironment.makeScanReader(options: options)
            let wordsPass = SearchWordsPass(
                library: store,
                today: today,
                suggester: suggester,
                preferences: preferences,
                isBusy: { wordsWriter.isWriting })
            flow = ScanFlowModel(
                cameraAccess: AppEnvironment.cameraAccess(options: options),
                clock: clock,
                analytics: analytics,
                suggester: suggester,
                // Read as each scan starts, so the Settings switch takes effect on the next one.
                suggestionsOn: { preferences.appleIntelligenceOn },
                makeReview: { input in
                    ReviewModel(
                        input: input,
                        reader: scanReader,
                        library: store,
                        clock: clock,
                        analytics: analytics,
                        readingWaitLimit: AppEnvironment.readingWaitLimit,
                        suggester: suggester,
                        suggestionsOn: preferences.appleIntelligenceOn,
                        suggestionWaitLimit: AppEnvironment.suggestionWaitLimit,
                        wordsWriter: wordsWriter
                    )
                },
                scanStarted: wordsPass.scanStarted,
                scanEnded: wordsPass.scanEnded
            )
            self.suggester = suggester
            self.wordsPass = wordsPass
            self.analytics = analytics
        }

        /// Settings, whose Apple Intelligence switch and reading line follow this model and pass.
        func settings(preferences: AppPreferences, notifications: any CleanupNotifying) -> SettingsModel {
            SettingsModel(
                preferences: preferences,
                notifications: notifications,
                suggester: suggester,
                wordsPass: wordsPass,
                analytics: analytics)
        }
    }

    private static func makeScanReader(options: LaunchOptions) -> ScanReader {
        #if DEBUG
            if options.fakeReader { return ScanReader(reader: FakeTextReader.readsCityPharmacy()) }
        #endif
        return ScanReader(reader: options.reader.makeReader())
    }

    /// The on-device model, or a scripted one for `-Suggestions`. UI tests get an unavailable one unless the flag says
    /// otherwise, so every journey keeps today's full sheet (M5).
    private static func makeSuggester(options: LaunchOptions) -> any ScanSuggester {
        #if DEBUG
            switch options.suggestions {
            case .arrives:
                return FakeScanSuggester(
                    filing: .arrives(FakeScanSuggester.cityPharmacy(), after: fakeSuggestionDelay),
                    words: .arrives(FakeScanSuggester.cityPharmacyWords, after: fakeSuggestionDelay))
            case .slow:
                return FakeScanSuggester(filing: .never, words: .never)
            case .unavailable:
                return FakeScanSuggester.unavailable()
            case nil:
                if options.isUITest { return FakeScanSuggester.unavailable() }
            }
        #endif
        return ModelScanSuggester()
    }
}
