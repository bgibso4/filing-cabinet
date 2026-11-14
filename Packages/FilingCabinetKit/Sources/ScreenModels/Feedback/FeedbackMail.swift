import Foundation

/// The emails the app drafts: plain feedback from Settings, and the report from the "library couldn't open" screen.
/// Built from device details and an error only, so no scan content can be in them.
package enum FeedbackMail {
    package static func feedback(_ details: DeviceDetails) -> URL {
        draft(subject: "Filing Cabinet feedback", body: body(details))
    }

    package static func report(_ details: DeviceDetails, error: any Error) -> URL {
        let nsError = error as NSError
        let errorLine = "Error: \(nsError.domain) \(nsError.code) · \(error.localizedDescription)"
        return draft(subject: "Filing Cabinet · library couldn't open", body: body(details) + "\n" + errorLine)
    }

    /// The alert's message when no mail app can open the draft.
    package static func noMailMessage(address: String) -> String {
        String(localized: "Send your note to \(address)", bundle: #bundle)
    }

    /// Room at the top for the person's own line, the details underneath.
    private static func body(_ details: DeviceDetails) -> String {
        "\n\n · · · \n" + details.detailsLine
    }

    private static func draft(subject: String, body: String) -> URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = FeedbackAddress.value
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: body),
        ]
        // Only fails for a scheme or path that isn't valid, and these are constants.
        guard let url = components.url else { preconditionFailure("The feedback draft is not a valid URL") }
        return url
    }
}
