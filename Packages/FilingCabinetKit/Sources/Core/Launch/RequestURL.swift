import Foundation

/// How a UI test sends a request from outside the app to the running app, as the Scan control, Siri or Spotlight do
/// when the app is already open or in the background: the app opens this URL and sends the request it carries. The
/// value is `-Request`'s (`scan`, `search:<text>`, `open:<n>`). Like `RelaunchURL`, the app acts on it only in a Debug
/// build that was itself launched with `-UITest`.
public enum RequestURL {
    private static let host = "request"
    private static let valueName = "value"

    /// The URL that sends the request `value` names.
    public static func make(_ value: String) -> URL? {
        var components = URLComponents()
        components.scheme = RelaunchURL.scheme
        components.host = host
        components.queryItems = [URLQueryItem(name: valueName, value: value)]
        return components.url
    }

    /// The request in a request URL, or nil when `url` is not one or its value names no request.
    public static func request(from url: URL) -> RequestFlag? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.scheme == RelaunchURL.scheme, components.host == host,
            let value = components.queryItems?.first(where: { $0.name == valueName })?.value
        else { return nil }
        return RequestFlag(value)
    }
}
