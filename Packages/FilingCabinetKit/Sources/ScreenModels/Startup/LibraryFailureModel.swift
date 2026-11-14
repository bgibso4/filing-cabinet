import Core
import Foundation
import Observation

/// The screen shown instead of the app when the library can't open (#40). Send report drafts an email with the error;
/// Try again asks the app to open the library again. Neither touches a file.
@Observable
public final class LibraryFailureModel {
    /// What VoiceOver hears after a Try again that failed (M3); nil until then.
    package private(set) var announcement: String?

    @ObservationIgnored private let error: any Error
    @ObservationIgnored private let details: DeviceDetails
    @ObservationIgnored private let analytics: any Analytics
    @ObservationIgnored private let retry: () -> Bool

    /// `retry` opens the library again and says whether it opened; when it did, the app replaces this screen.
    public init(
        error: any Error, details: DeviceDetails = .current(), analytics: any Analytics, retry: @escaping () -> Bool
    ) {
        self.error = error
        self.details = details
        self.analytics = analytics
        self.retry = retry
    }

    /// The report Send report opens: the app and iPhone details and the error, nothing from the library.
    package var reportURL: URL { FeedbackMail.report(details, error: error) }

    /// Send report was tapped.
    package func reportOpened() { analytics.send(.feedbackOpened(kind: .report)) }

    /// Try again was tapped. Only ever on a tap: the screen never retries by itself.
    package func tryAgain() {
        announcement = retry() ? nil : String(localized: "Still couldn’t open", bundle: #bundle)
    }
}
