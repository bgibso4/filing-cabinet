import Core
import Foundation
import Observation
import Understanding

/// The Settings screen (10-01): the collections count, the Apple Intelligence and Notifications switches and the
/// footers.
@Observable
public final class SettingsModel {
    package private(set) var authorization = NotificationAuthorization.notDetermined

    @ObservationIgnored private let preferences: AppPreferences
    @ObservationIgnored private let notifications: any CleanupNotifying
    @ObservationIgnored private let suggester: any ScanSuggester
    @ObservationIgnored private let wordsPass: SearchWordsPass
    @ObservationIgnored private let version: String

    public init(
        preferences: AppPreferences,
        notifications: any CleanupNotifying,
        suggester: any ScanSuggester,
        wordsPass: SearchWordsPass,
        version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    ) {
        self.preferences = preferences
        self.notifications = notifications
        self.suggester = suggester
        self.wordsPass = wordsPass
        self.version = version
    }

    package var appearance: AppearanceChoice { preferences.appearance }

    package func setAppearance(_ choice: AppearanceChoice) { preferences.appearance = choice }

    package var collectionsCount: Int { BuiltInCollection.allCases.count }

    /// On only when the person wants notes and iOS allows them.
    package var notificationsSwitchIsOn: Bool { preferences.notesReach(given: authorization) }

    package var notificationsNote: String {
        authorization == .denied
            ? String(localized: "Turned off in iPhone Settings", bundle: #bundle)
            : String(localized: "A note when scans move to Trash", bundle: #bundle)
    }

    /// Read fresh: the model can become available, or stop being, while the app runs.
    package var intelligence: IntelligenceRow {
        let isAvailable = suggester.availability == .available
        let progress = isAvailable ? wordsPass.progress : nil
        return IntelligenceRow(
            isAvailable: isAvailable,
            isOn: suggester.answers(whenOn: preferences.appleIntelligenceOn),
            subtitle: isAvailable
                ? String(localized: "Names, files and finds your scans", bundle: #bundle)
                : String(localized: "Turn it on in iPhone Settings first", bundle: #bundle),
            footer: Self.intelligenceFooter(isAvailable: isAvailable, progress: progress),
            progress: progress.map { Double($0.done) / Double(max($0.total, 1)) })
    }

    /// The switch was flipped: the next scan follows it, and the reading of older scans stops or starts again. Words
    /// already stored keep working in Search.
    package func setIntelligence(_ isOn: Bool) {
        preferences.appleIntelligenceOn = isOn
        if isOn {
            wordsPass.resume()
        } else {
            wordsPass.pause()
        }
    }

    package var footer: String {
        String(localized: "Filing Cabinet \(version) · Private by design", bundle: #bundle)
    }

    /// Reads what iOS currently allows; the screen calls it as it appears and when the app comes back.
    public func refreshAuthorization() async {
        authorization = await notifications.authorization()
    }

    /// The switch was flipped. Turning on asks iOS the first time (M3). When iOS had already blocked notes before
    /// the tap, only iPhone Settings can change it, so the caller gets `.openSystemSettings`; a refusal of the
    /// ask made by this very call returns nil.
    package func setNotifications(_ isOn: Bool) async -> SettingsAction? {
        guard isOn else {
            preferences.notificationsOn = false
            return nil
        }
        await refreshAuthorization()
        if authorization == .denied { return .openSystemSettings }
        if authorization == .notDetermined {
            _ = await notifications.requestAuthorization()
            await refreshAuthorization()
        }
        // The person's wish is on even if they just refused iOS's ask, as it is by default: the switch still shows
        // off (notes don't reach them), and if they later allow notes in iPhone Settings, notes start without
        // another tap here.
        preferences.notificationsOn = true
        return nil
    }

    private static func intelligenceFooter(isAvailable: Bool, progress: SearchWordsPass.Progress?) -> String? {
        guard isAvailable else { return nil }
        guard let progress else {
            return String(localized: "Runs on this iPhone. Your scans never leave it.", bundle: #bundle)
        }
        // No-break spaces keep "· 12 of 91" together when the line wraps.
        return String(
            localized:
                "Reading your older scans so search can find them ·\u{00A0}\(progress.done)\u{00A0}of\u{00A0}\(progress.total)",
            bundle: #bundle)
    }
}
