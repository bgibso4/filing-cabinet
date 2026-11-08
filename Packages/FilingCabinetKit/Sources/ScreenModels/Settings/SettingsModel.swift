import Core
import Foundation
import Observation

/// The Settings screen (10-01): the collections count, the Notifications switch and the footer.
@Observable
public final class SettingsModel {
    package private(set) var authorization = NotificationAuthorization.notDetermined

    @ObservationIgnored private let preferences: AppPreferences
    @ObservationIgnored private let notifications: any CleanupNotifying
    @ObservationIgnored private let version: String

    public init(
        preferences: AppPreferences,
        notifications: any CleanupNotifying,
        version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    ) {
        self.preferences = preferences
        self.notifications = notifications
        self.version = version
    }

    package var collectionsCount: Int { BuiltInCollection.allCases.count }

    /// On only when the person wants notes and iOS allows them.
    package var notificationsSwitchIsOn: Bool { preferences.notesReach(given: authorization) }

    package var notificationsNote: String {
        authorization == .denied
            ? String(localized: "Turned off in iPhone Settings", bundle: #bundle)
            : String(localized: "A note when scans move to Trash", bundle: #bundle)
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
}
